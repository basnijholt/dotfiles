# PC ZFS Migration Plan

**WARNING: THIS PROCESS WIPES THE ROOT DRIVE — Samsung 990 EVO Plus 4TB
(`/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0Y206553P`,
`/dev/nvme1n1` today). ENSURE BACKUPS AND THE MIGRATION KIT ARE SAFE FIRST.**

Target layout (from `common/disko-zfs.nix`, the same module hp and nuc use):

- 512M vfat ESP at `/boot`, GRUB with `copyKernels` (the old `/boot2` name dies here)
- 96G swap partition — the btrfs swapfile cannot come along; swapfiles are not supported on ZFS
- `zroot` pool: `root` → `/`, `nix` → `/nix`, `var` → `/var`, `home` → `/home`
  (legacy mounts, zstd, xattr=sa, atime off)

Snapshots and replication come from the fleet-standard modules
(`optional/zfs-sanoid.nix` + `optional/zfs-replication.nix`, imported via
`hosts/pc/default.nix`) — no snapper, no manual snapshot config.

## Phase 0: Preparation (BEFORE wiping anything)

1. **Verify restic backups are fresh.** pc backs up hourly to the NAS
   (NixOS, since the 2026-06 cutover): `sftp:restic@192.168.1.4:/mnt/tank/backups/pc`.

   ```bash
   systemctl status restic-backups-truenas.service   # last run must be recent + successful
   sudo restic-truenas snapshots --latest 1          # wrapper from services.restic
   ```

2. **Refresh the Migration Kit** (`~/MIGRATION_KIT`, mirrored to
   `basnijholt@nuc:~/MIGRATION_KIT`). It must contain *current* copies of:
   - `/root/.ssh/restic-backup` (SSH key the restic sftp backend uses)
   - `/root/.restic-password` (repo encryption password)
   - `/etc/ssh/ssh_host_*` (host identity)
   - `/etc/munge/munge.key` (Slurm cluster auth)
   - `restore_from_backup.sh`

3. **Copy the kit to a USB stick** or verify the nuc mirror is current.
   *Losing this folder means losing backup access and system identity.*

4. **Push this branch** and make sure CI/eval is green.

## Phase 1: Wipe & Install

1. Boot the NixOS installer USB, get network access, then:

   ```bash
   sudo -i
   nix --extra-experimental-features 'nix-command flakes' \
     run github:nix-community/disko -- \
     --mode destroy,format,mount \
     --flake 'github:basnijholt/dotfiles/pc-zfs?dir=configs/nixos#pc'

   nixos-install --no-root-passwd \
     --flake 'github:basnijholt/dotfiles/pc-zfs?dir=configs/nixos#pc'

   reboot
   ```

   (After the PR merges, use `.../dotfiles/main?dir=configs/nixos#pc`.)

## Phase 2: Restore Data & Identity

1. Fetch the kit: `scp -r basnijholt@nuc:~/MIGRATION_KIT .` (or from USB).
2. `cd MIGRATION_KIT && sudo ./restore_from_backup.sh` — restores `/home`,
   `/var/lib/*` (qdrant, incus, ollama, libvirt, munge) from the latest
   restic snapshot and puts SSH host keys + munge key back with correct
   permissions.
3. Reboot.

## Phase 3: Verification & ZFS Wiring

1. **Pool:** `zpool status` shows `zroot` ONLINE; `swapon --show` shows the 96G partition.
2. **Identity:** `ssh pc` from another machine accepts the old host key.
3. **Snapshots:** within ~10 minutes sanoid creates `autosnap_*`:
   `zfs list -t snapshot | head`.
4. **Replication to the NAS** (one-time setup, see comments in
   `optional/zfs-replication.nix`):
   - On the NAS: `sudo zfs create tank/backups/pc`
   - Add pc's root SSH key to the NAS `/etc/ssh/authorized_keys.d/root`
     (restored from backup, so likely already in place — verify with
     `sudo ssh root@192.168.1.4 zfs list`)
   - First run: `sudo systemctl start zfs-replication` (daily timer after that)
5. **Services:** `systemctl status slurmd qdrant ollama` — active, using restored state.
6. **Incus:** if recreating its storage pool on ZFS (like hp's `zroot/incus`),
   also copy hp's sanoid exclusion into `hosts/pc/default.nix` so sanoid
   stays away from incus-managed datasets.
