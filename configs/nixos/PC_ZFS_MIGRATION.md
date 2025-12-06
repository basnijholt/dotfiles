# PC ZFS Migration Plan

**WARNING: THIS PROCESS WILL WIPE THE ROOT DRIVE (`/dev/nvme1n1`). ENSURE ALL DATA IS BACKED UP AND MIGRATION KIT IS SAFE.**

## Phase 0: Preparation (Do this BEFORE wiping)

1.  **Verify Backup Access (Completed):**
    *   We confirmed that `restic` access to TrueNAS works using the key `restic-backup`.
    *   We confirmed the latest snapshot is available.

2.  **Create Migration Kit (Completed):**
    *   A folder `~/MIGRATION_KIT` has been created and synced to your NUC (`basnijholt@nuc:~/MIGRATION_KIT`).
    *   It contains:
        *   `restic-backup` (Private Key for TrueNAS access)
        *   `.restic-password` (Repo encryption password)
        *   `ssh_host_*` (Original SSH host keys to preserve identity)
        *   `munge.key` (For Slurm cluster auth)
        *   `restore_from_backup.sh` (Automated restore script)

3.  **Backup the Migration Kit (CRITICAL):**
    *   Ensure `~/MIGRATION_KIT` is copied to a **USB Stick** OR verified to be on the **NUC**.
    *   *If you lose this folder, you lose access to your backups and your system identity.*

4.  **Sync Git:**
    *   Ensure all config changes are pushed:
    ```bash
    git add . && git commit -m "refactor(pc): migrate to zfs" && git push origin pc-zfs
    ```

## Phase 1: Wipe & Install

1.  **Boot Installer:** Reboot `pc` with the NixOS installer USB.
2.  **Connect Network:** Ensure you have internet access.
3.  **Partition & Format:**
    ```bash
    sudo -i
    # Use the 'pc-zfs' branch explicitly
    nix --extra-experimental-features 'nix-command flakes' \
      run github:nix-community/disko -- \
      --mode destroy,format,mount \
      --flake 'github:basnijholt/dotfiles/pc-zfs#pc'
    ```
4.  **Install NixOS:**
    ```bash
    nixos-install --flake 'github:basnijholt/dotfiles/pc-zfs#pc' --no-root-passwd
    ```
5.  **Reboot:**
    ```bash
    reboot
    ```

## Phase 2: Restore Data & Identity

*After rebooting into your fresh ZFS system:*

1.  **Retrieve Migration Kit:**
    *   **Option A (From NUC):**
        ```bash
        scp -r basnijholt@nuc:~/MIGRATION_KIT .
        ```
    *   **Option B (From USB):**
        Mount USB and copy `MIGRATION_KIT` to your home folder.

2.  **Run Restore Script:**
    This script will:
    *   Connect to TrueNAS using the verified keys.
    *   Restore data (`/home`, `/etc/nixos`, `/var/lib/*`) from the latest snapshot.
    *   **Automatically restore** SSH host keys, Munge key, and Root keys to `/etc/` and `/root/` with correct permissions.

    ```bash
    cd MIGRATION_KIT
    sudo ./restore_from_backup.sh
    ```

3.  **Final Reboot:**
    ```bash
    reboot
    ```

## Phase 3: Verification

1.  **Check ZFS:** `zpool status` (Should show `zroot` online).
2.  **Check Identity:** `ssh localhost` (Should accept your known host key).
3.  **Check Services:** `systemctl status slurmd` (Should be active if munge key is correct).

