# 4 TB NVMe Migration Plan

This document guides a fresh agent through migrating NixOS to a new 4 TB Samsung 990 EVO Plus NVMe drive using declarative tooling (disko + nixos-install) without booting an external installer.

## Objectives
- Recreate system layout on the new SSD with reproducible partitioning and Btrfs subvolumes.
- Relocate high-growth services (Ollama, llama-swap models, Qdrant) onto the new drive under `/var/lib`.
- Preserve the existing dual-boot Windows installation on `nvme0n1` and keep the current system operational until cutover.
- Provide validation and rollback checkpoints so the operator can stop before switching the boot order if anything looks wrong.

## Environment Snapshot
- Repo: `/home/basnijholt/dotfiles/configs/nixos`
- Hostname: `nixos`
- Existing root: `nvme0n1p6` mounted on `/` (ext4) with `/boot` on `nvme0n1p3` (EFI shared with Windows).
- New hardware: empty 4 TB Samsung 990 EVO Plus NVMe expected as `/dev/nvme1n1`.
- Services with heavy storage needs: `services.ollama`, `systemd.services.llama-swap` models, `services.qdrant`, restic backups (`configuration.nix:572`), plus optional VM/container data.

## High-Level Strategy
1. Describe the new disk layout declaratively via a disko module.
2. Teach the system configuration about new mount points and service paths.
3. Run disko from the live system to partition/format/mount the new drive (dry-run first).
4. Install NixOS to the mounted target using `nixos-install --flake` from the current system.
5. Validate the new root via `nixos-enter`, adjust firmware boot order, and clean up the old root when satisfied.

## Task Breakdown

### 1. Repository Updates (✅ COMPLETED)
Goal: Capture disk + service changes in Git so the layout is reproducible.

- [x] Add `disko-new-ssd.nix` describing the GPT + Btrfs layout:
  - Disk `/dev/nvme1n1`, 512 MiB ESP, remainder Btrfs.
  - Subvolumes: `@root`→`/`, `@nix`→`/nix`, `@var`→`/var`, `@home`→`/home`, optional `@snapshots` if desired.
  - Mount options: `compress=zstd`, `noatime`, `discard=async`, `space_cache=v2`.
- [x] Import the module in `flake.nix` and expose it via `diskoConfigurations.nvme1`.
- [x] Update `configuration.nix` overrides:
  - Qdrant storage/snapshot paths → `/var/lib/qdrant/...`.
  - `services.restic.backups.truenas.paths` includes `/var/lib/qdrant` and `/var/lib/ollama`.
  - `services.fstrim.enable = true;` plus tmpfiles rules for `/var/lib/qdrant` and `/var/lib/ollama`.
- [x] Stage but defer commit until the new install is validated.

### 2. Disk Provisioning with Disko (✅ COMPLETED)
Goal: Let Nix perform destructive steps safely with preview.

1. Confirm device mapping:
   ```bash
   lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS
   ls -l /dev/disk/by-path | grep nvme
   ```
   - The empty 4 TB drive must appear as `nvme1n1` (e.g. `pci-0000:04:00.0-nvme-1`).
2. Dry run disko (already done once, keep command for reference):
   ```bash
   sudo nix run github:nix-community/disko -- --flake .#nvme1 --mode format,mount --dry-run
   ```
   - Review output; confirm only `/dev/nvme1n1` is touched.
3. Real run (destructive, formats and mounts under `/mnt`):
   ```bash
   sudo nix run github:nix-community/disko -- --flake .#nvme1 --mode format,mount
   ```
4. Optional sanity checks (`findmnt /mnt`, `sudo btrfs subvolume list /mnt`).
5. If an `@ai` subvolume was created during earlier runs, remove it now so `/var/lib` stays within `@var`:
   ```bash
   sudo umount /mnt/var/lib/ai 2>/dev/null || true
   sudo nix run nixpkgs#btrfs-progs -c btrfs subvolume delete /mnt/var/lib/ai 2>/dev/null || true
   ```

### 3. Install System onto New Drive (✅ COMPLETED)
Goal: Copy current system using the new layout without rebooting.

1. Copy data onto the new mounts before installation:
   ```bash
   sudo rsync -aAX --info=progress2 /home/ /mnt/home/
   sudo rsync -aAX --info=progress2 /etc/nixos/ /mnt/etc/nixos/
   # Optional: copy targeted /var subdirectories, e.g.
   sudo rsync -aAX --info=progress2 /var/lib/qdrant/ /mnt/var/lib/qdrant/
   sudo rsync -aAX --info=progress2 /var/lib/ollama/ /mnt/var/lib/ollama/
   ```
2. Bind mount supporting filesystems:
   ```bash
   sudo mount --rbind /dev /mnt/dev
   sudo mount --rbind /proc /mnt/proc
   sudo mount --rbind /sys /mnt/sys
   ```
   (If disko already mounted to a different root, adjust paths accordingly.)
3. Run installer:
   ```bash
   sudo nixos-install --flake .#nixos --root /mnt --no-root-passwd
   ```
   - This builds the system and populates `/mnt` according to flake modules.
4. Optional: capture resulting hardware UUIDs (`sudo blkid`) and inspect `/mnt/etc/nixos/hardware-configuration.nix`.

### 4. Pre-Cutover Validation (✅ COMPLETED)
Goal: sanity-check the new environment before rebooting.

- [x] Enter the new root: `sudo nixos-enter --root /mnt`.
- [x] Confirm key services resolve to the new paths (`ls -al /var/lib/ollama`, `/var/lib/qdrant` etc.).
- [x] Ensure `/boot` still points to the existing EFI or the new `/boot2` is populated.
- [x] Exit chroot and run `nixos-rebuild test --flake .#nixos` from the host to catch compilation issues.
- [x] Optionally run `sudo btrfs filesystem usage /mnt` to check compression and free space.
- [x] When done, unmount bind mounts: `sudo umount -R /mnt/dev /mnt/proc /mnt/sys`.

### 5. Cutover & Cleanup
Goal: Switch to the new drive and tidy up.

- [x] Reboot into firmware settings, set the 4 TB drive's EFI entry (or GRUB on it) to highest priority. ✅ COMPLETED
- [x] Verify the system boots from Btrfs root (`mount | grep "subvol=@"`). ✅ COMPLETED
- [x] Configure `/boot2` as the new EFI partition independent from Windows. ✅ COMPLETED (2024-09-20)
- [ ] **PLANNED (in a few days)**: Delete old NixOS ext4 root (`nvme0n1p6`) while preserving Windows dual-boot.
- [ ] After old system deletion: Repurpose `nvme0n1p6` for additional storage or leave unallocated.
- [ ] Consider creating a fresh restic snapshot to capture the new layout.

## Migration Status (2024-09-20)
- ✅ Successfully migrated to 4TB NVMe drive
- ✅ System running on Btrfs with compression (zstd)
- ✅ Bootloader configured on `/boot2` (new drive's EFI partition)
- ✅ All services (Ollama, Qdrant, llama-swap) operational on new drive
- ⏳ Old NixOS installation on `nvme0n1p6` to be removed in a few days
- ✅ Windows dual-boot preserved on `nvme0n1p3`

## Validation & Rollback Points
- Disko dry-run before formatting.
- Post-format mount inspection (`findmnt`, `btrfs subvolume list`).
- `nixos-install` build logs: stop if evaluation fails.
- `nixos-enter` checks before first reboot.
- Firmware boot order change is the only irreversible step; do it last.
- To revert prior to cutover, unmount `/mnt`, re-run `nix run … --mode umount`, and leave the old system untouched.
- The original `nvme0n1` remains untouched until you deliberately reuse or wipe it.

## Additional Notes
- Update any other services storing data under `/var/lib` (e.g., containers) if they need the new capacity.
- If hibernation is desired later, consider adding an extra swap subvolume or partition in the disko module.
- Documented commands assume Z shell; adjust quoting if scripting elsewhere.
- Keep the Windows ESP mounted read-only (`/boot`) and treat the second ESP (`/boot2`) as backup; you can later sync files using `systemd` units or leave it unused.
- After the first boot on Btrfs, consider running a restic backup immediately to capture the new layout.