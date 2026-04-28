# NixOS ⇄ Proxmox Migration Playbook

_(Generated October 9, 2025 to document the current workstation and Proxmox cluster state, plus a staged migration strategy.)_

## 1. Host Context

### 1.1 Workstation (`pc` / `nixos`)
- OS: NixOS 25.11 (kernel 6.12.49).
- Hardware: Ryzen 9 3900X (24 threads), RTX 3090 (driver 580.95.05, CUDA 13.0).
- Storage:
  - `/dev/nvme1n1` → Btrfs with subvolumes `@root`, `@nix`, `@var`, `@home`, `@snapshots` (mounted via `hosts/pc/disko.nix`).
  - `/dev/nvme1n1p1` mounted on `/boot2` (EFI).
  - `/dev/nvme0n1` retains Windows partitions.
- Services enabled via shared modules: Docker, libvirtd, Incus, Tailscale, Syncthing, Snapper, restic backups to `truenas.local`.
- GPU services: `services.ollama`, llama-swap systemd unit, Wyoming (speech), Qdrant DB.
- Virtualisation tooling already installed (`qemu-system-x86_64 10.1.0`, `virt-manager`, Incus 6.0.5); `/dev/kvm` currently missing → load `kvm-amd` before KVM workloads.

### 1.2 Proxmox Node (`hp` @ `192.168.1.26`)
- Platform: Proxmox VE 9.0.10 (Debian 13 base, kernel 6.14.11-2-pve), Intel i5-8500, 62 GiB RAM, single `nvme0n1` (238 GB) ZFS `rpool`.
- VM inventory (`qm list`):
  | VMID | Name             | State    | vCPU | RAM   | Disks                                           |
  |------|------------------|----------|------|-------|------------------------------------------------|
  | 100  | haos             | running  | 3    | 16 GB | raw 57 GB (`vm-100-disk-1`) + EFI stub + USB passthrough |
  | 105  | truenas-jbweston | stopped  | 2    | 4 GB  | 32 GB + two 1 TB iSCSI volumes (`jbweston1/2`) |
  | 108  | nixos            | stopped  | 2    | 4 GB  | 32 GB raw (`vm-108-disk-0`), ISO attached       |
- Container inventory (`pct list`): LXCs 101–128, multiple helper-script templates with device passthrough (USB serial, `/dev/dri`, `/dev/net/tun`).
- Storage state (`zfs list`, `pvesm status`): `rpool` 197 GB used/31.9 GB free; `local-zfs` 74 % utilized; `backup` directory 75 % utilized.

## 2. Artifacts Captured for Testing
- `vm-imports/vm-108-disk-0.raw`: 32 GiB raw copy of `hp` VM 108 (created with `dd if=/dev/zvol/rpool/data/vm-108-disk-0 bs=8M status=progress`).
- `vm-imports/run-vm-108.sh`: executable helper to boot the raw disk under QEMU (`-machine q35`, `virtio` drive/net, configurable display, default SSH forward host port `22222`).
- `vm-imports/108.conf`: Proxmox configuration dump for VM 108 for reference.

## 3. Proxmox-NixOS (SaumonNet) Notes
- Flake repo: `github:SaumonNet/proxmox-nixos` (cloned under `/tmp/tmp.mCGzw73d1b`).
- Provides overlays for Proxmox VE 8.4.13 packages and modules `proxmox-ve`, `proxmox-backup`, `declarative-vms`.
- `services.proxmox-ve` module:
  - Enables pvedaemon/pveproxy/pvestatd/qmeventd, rpcbind, `www-data` user, firewall openings (80/111/443/8006, UDP 111 & 5405–5412).
  - Writes `/etc/network/interfaces` for declared bridges; actual bridge creation left to Nix networking.
  - Expects `/dev/kvm` and optional Linstor/Cluster components (imported but can be disabled).
- Declarative VM support: `services.proxmox-ve.vms.<name>` triggers one-shot creation via `pvesh create` if VMID free; for ongoing management prefer `virtualisation.proxmox` module + `nixmoxer` CLI.
- `nixmoxer`: Python tool using Proxmox API to bootstrap VMs from evaluated Nix configs, supports ISO upload + optional autoInstall.

### 3.1 Activation Considerations
1. **Kernel modules** – ensure `kvm-amd`, `kvm`, `vhost_vsock` load before enabling proxmox services.
2. **Networking** – decide on host bridge names (e.g., `vmbr0` matching Proxmox defaults) and configure via `networking.bridges` or `systemd-networkd` before enabling the module.
3. **Port conflicts** – proxmox UI uses 8006/443/80; coordinate with Synapse, Tailscale admin, or reverse proxies already bound on pc host.
4. **Storage layout** – module expects `/var/lib/pve`; map Btrfs subvolumes or dedicated dataset to avoid polluting root.
5. **AppArmor / Security** – proxmox components may warn if AppArmor missing; align with NixOS hardening options if re-enabling AppArmor later.

## 4. Declarative Proxmox Guests with `nixos-generators`
- Reference: Josh Lee’s “NixOS + Proxmox: A Recipe for a Declarative Homelab,” Sept 5 2024. citeturn0web_fetch0
- Key features:
  - `nixos-generators` supports `-f proxmox` output to produce `.vma.zst` artifacts.
  - Base config should import `profiles/qemu-guest.nix`, enable `services.qemuGuest`, `boot.growPartition`, and reference root by `/dev/disk/by-label`.
  - `nix.settings.trusted-users` + `experimental-features = ["nix-command" "flakes"]` allow remote rebuilds.
  - Keep system packages minimal (e.g., `vim`, `git`, `python3`) and manage user + SSH key inline for first-boot access.
- Workflow outline:
  1. Write guest flake/module (host-specific overlays for packages/services).
  2. `nix shell nixpkgs#nixos-generators -c nixos-generate -f proxmox -c ./guest.nix -o ./artifacts/guest`.
  3. Upload `.vma` to Proxmox storage (`scp` to `/var/lib/vz/dump/`).
  4. Restore with `qmrestore ... --storage local-zfs`.
  5. Update live guest using `nixos-rebuild --flake .#guest --target-host user@guest --use-remote-sudo` (optionally add `--build-host` to compile on pc host).

## 5. Migration Strategy

### 5.1 Phase 0 – Preparation
1. Verify git status of `/home/basnijholt/dotfiles/configs/nixos`; commit current state before large changes.
2. Ensure restic backups succeed (restic SFTP to `truenas.local`) before tampering with virtualization stack.
3. Document BIOS/UEFI toggles (SVM, IOMMU) and confirm virtualization enabled for both hosts.

### 5.2 Phase 1 – Proxmox-NixOS Sandbox
1. Add flake input and `nixosConfigurations.proxmox-lab` using the proxmox module.
2. `nix build .#nixosConfigurations.proxmox-lab.config.system.build.vm` then boot image to validate proxmox services in isolation.

### 5.3 Phase 2 – Optional Proxmox Services on pc Host
1. Configure bridge `vmbr0` (via `networking.bridges`), load `kvm-amd`.
2. Enable `services.proxmox-ve` with `openFirewall = false` if nftables already manages ports.
3. `nixos-rebuild test --flake .#nixos`; verify `pvedaemon`, `pveproxy`, API endpoint.

### 5.4 Phase 3 – VM Migration Options
**Raw import:** `qemu-img convert -f raw -O qcow2 vm-imports/vm-108-disk-0.raw vm-108.qcow2`, then `qm importdisk 108 vm-108.qcow2 local-zfs`.

**Declarative image:** implement guest module, run `nixos-generate -f proxmox`, `qmrestore` onto destination.

**API bootstrap:** define `virtualisation.proxmox` in guest config and run `nix run github:SaumonNet/proxmox-nixos#nixmoxer -- --flake guest`.

### 5.5 Phase 4 – LXC Container Strategy
1. `ssh hp pct backup <id> --mode stop --compress zstd`.
2. Transfer tarball; `incus image import backup.tar.zst --alias <name>` then configure Incus profile for USB/DRI/TUN.
3. Optionally translate workloads into declarative NixOS services or Docker Compose for long-term maintenance.

### 5.6 Phase 5 – Rebuild `hp` with NixOS (later)
1. Evacuate VMs/CTs, boot NixOS installer ISO, apply `disko` for new layout.
2. Configure `hosts/hp` flake to run proxmox-nixos or remain as a pure Nix hypervisor.

## 6. Operational Checklists
- After changes: `systemctl status pvedaemon pveproxy pvestatd qmeventd`, `curl -k https://<ip>:8006/api2/json`, `ls /dev/kvm`.
- Monitor Docker/Incus/k8s services to ensure proxmox ports do not collide with existing workloads.
- Update restic include paths with `/var/lib/pve` once proxmox assets relocate.

## 7. Reference Commands
```bash
hostnamectl
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
ssh hp qm list
ssh hp pct list
ssh hp zfs list
ssh hp pvesm status
ssh hp dd if=/dev/zvol/rpool/data/vm-108-disk-0 bs=8M status=progress > vm-imports/vm-108-disk-0.raw
qemu-img info vm-imports/vm-108-disk-0.raw
```

## 8. External References
- Josh Lee, “NixOS + Proxmox: A Recipe for a Declarative Homelab,” Sept 5 2024. citeturn0web_fetch0
- SaumonNet `proxmox-nixos` flake (Proxmox VE modules, `nixmoxer`).

