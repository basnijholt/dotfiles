# Bas Nijholt's NixOS configs

## 3-Tier Module Architecture

```
configs/nixos/
├── common/           # Tier 1: shared by ALL hosts
├── optional/         # Tier 2: opt-in modules (desktop, audio, virtualization, power, etc.)
├── hosts/            # Tier 3: host-specific (pc, nuc, hp)
├── secrets/          # Agenix encrypted secrets
├── installers/       # ISO builder
└── archive/          # Old migration scripts/notes
```

## Configurations

| Config | Type | Description |
|--------|------|-------------|
| `pc` | Physical | Desktop/workstation (NVIDIA, Hyprland, AI services) |
| `nuc` | Physical | Media box (Kodi, Btrfs, desktop + power management) |
| `hp` | Physical | Headless server (ZFS, virtualization + power management) |
| `pi3` | Physical | Raspberry Pi 3 - lightweight headless server (aarch64) |
| `pi4` | Physical | Raspberry Pi 4 - lightweight headless server (aarch64) |
| `hp-incus` | Incus VM | HP config for Incus VM testing |
| `nuc-incus` | Incus VM | NUC config for Incus VM testing |
| `pc-incus` | Incus VM | PC config for Incus VM testing (GPU services build but won't run) |
| `dev-vm` | Incus VM | Lightweight dev environment (x86_64) |
| `dev-lxc` | Incus LXC | Lightweight dev container (x86_64) |
| `swarm-vm` | Incus VM | Docker Swarm manager node (ZFS, part of HA cluster) |
| `nix-cache` | Incus LXC | Nix cache server with Harmonia (for CUDA/large builds) |
| `installer` | ISO | Minimal installer with SSH enabled |
| `pi3-bootstrap` | SD Image | Minimal Pi 3 bootstrap with WiFi + SSH |
| `pi4-bootstrap` | SD Image | Minimal Pi 4 bootstrap with WiFi + SSH |

## Quick Commands

```bash
# Build a system
nix build .#nixosConfigurations.hp.config.system.build.toplevel

# Build installer ISO
nix build .#nixosConfigurations.installer.config.system.build.isoImage
cp result/iso/*.iso /tmp/nixos.iso
```

## Install Cheatsheet

Boot from installer ISO, then:

```bash
# Partition and mount (replace #hp with #nuc for NUC)
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
  --mode destroy,format,mount --yes-wipe-all-disks \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#hp

# Install
nixos-install --root /mnt --no-root-passwd \
  --option substituters "http://nix-cache.local:5000 https://cache.nixos.org https://nix-community.cachix.org https://cache.nixos-cuda.org" \
  --option trusted-public-keys "build-vm-1:CQeZikX76TXVMm+EXHMIj26lmmLqfSxv8wxOkwqBb3g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#hp
```

For Incus VM installation, see the instructions in:
- `hosts/hp/incus-overrides.nix` (HP VM)
- `hosts/nuc/incus-overrides.nix` (NUC VM)
- `hosts/pc/incus-overrides.nix` (PC VM)
- `scripts/create-dev-vm.sh` (dev-vm helper script)

> **Note:** Default password is `nixos`. Change it after first boot with `passwd basnijholt`.

## Nix Cache Server Setup (nix-cache)

See [hosts/nix-cache/README.md](./hosts/nix-cache/README.md) for instructions on setting up the cache server container with Harmonia.

## Docker Swarm HA Cluster

Three-node high-availability Docker Swarm cluster across hp, nuc, and swarm-vm.

**Configuration:**
```nix
my.swarm.bootstrap = "br0";  # hp - creates cluster
my.swarm.join = "br0";       # nuc, swarm-vm - join as managers
```

**Deployment:**
1. Deploy HP first: `nixos-rebuild switch --flake .#hp`
2. Encrypt token: `ssh hp "sudo cat /root/secrets/swarm-manager.token" | agenix -e swarm-manager.token.age`
3. Deploy others: `nixos-rebuild switch --flake .#nuc`
4. Verify: `docker node ls`

See [plan.md](./plan.md) for detailed setup notes and troubleshooting.

## Secrets (agenix)

See [secrets/README.md](./secrets/README.md) for setup and usage.
