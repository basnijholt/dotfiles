# Direct SSD Installation Guide for Raspberry Pi 4 (ZFS Root)

This guide documents how to install NixOS directly onto an external USB SSD (Samsung T5) for a Raspberry Pi 4, using an x86_64 host PC.

## 🛠 Prerequisites

Ensure your host PC has the following configured:

1.  **ARM Emulation (binfmt):**
    Required to build ARM packages on x86.
    ```nix
    # configuration.nix
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    ```

2.  **ZFS Support:**
    Required to format the target drive with ZFS.
    ```nix
    # configuration.nix
    boot.supportedFilesystems = [ "zfs" ];
    networking.hostId = "8425e349"; # Required for ZFS (any random 8-char hex)
    ```

3.  **Apply Changes:**
    Run `sudo nixos-rebuild switch` and **REBOOT** to load the kernel modules.

## 🚀 Installation Procedure

We use a unified script to handle partitioning, building, installing, and bootloader injection.

1.  **Connect the Samsung T5 SSD** to your PC.
2.  **Run the Installer:**
    ```bash
    ./install_pi4_ssd.sh
    ```
    *(Follow the prompts. It will ask for sudo password).*

3.  **Deployment:**
    *   Unplug SSD from PC.
    *   Plug into Pi 4 (Blue USB 3.0 port).
    *   **Remove any SD card** (to force USB boot).
    *   Power on.

## ℹ️ How it Works

The script performs the following steps (detailed comments are inside `install_pi4_ssd.sh`):

1.  **Partitioning:** Uses `disko` to wipe the drive and create GPT partitions (ESP + ZFS).
2.  **Build:** Compiles the full system closure (`.#pi4`) for `aarch64` on your host machine.
3.  **Install:** Copies the system closure to the SSD.
    *   *Note:* It handles the common `chroot` activation failure gracefully.
4.  **Bootloader Injection:** Manually installs:
    *   Raspberry Pi Firmware (`start4.elf`, etc.)
    *   U-Boot (`u-boot-rpi4.bin`)
    *   Extlinux Configuration (`extlinux.conf`) pointing to the specific Nix store paths.

## ⚠️ Troubleshooting

*   **ZFS Module Error:** If the script fails saying ZFS is not loaded, ensure you have rebooted after enabling ZFS in your config.
*   **Disk Not Found:** Check that the SSD is plugged in and recognized as the ID specified in `install_pi4_ssd.sh`.
