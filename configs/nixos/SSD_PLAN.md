# Comprehensive Plan: Direct SSD Installation for Raspberry Pi 4

## Backstory & Context
We are attempting to provision a **Raspberry Pi 4** as a headless, declarative NixOS server. The constraints are strict:
*   **Root Filesystem:** ZFS on an external USB SSD (Samsung T5).
*   **Networking:** WiFi only (Pi is glued to a wall, no Ethernet access).
*   **Headless:** No monitor or keyboard attached.

### Previous Attempts (The "Bootstrap" Saga)
We initially tried a "Chicken and Egg" bootstrap approach:
1.  **"Hijack" Method:** Tried to use `nixos-anywhere` to hijack the existing DietPi/Debian installation.
    *   *Failure:* The DietPi kernel lacked `kexec` support ("Function not implemented"), making soft-reboot into the installer impossible.
2.  **Custom SD Image:** We built a custom `pi4-bootstrap.img` with SSH keys and WiFi credentials baked in.
    *   *Challenge 1 (Cross-compilation):* Built on macOS using Docker to handle Linux/Aarch64 generation.
    *   *Challenge 2 (Missing Drivers):* The minimal image stripped the Broadcom WiFi driver (`brcmfmac`). We fixed this by forcing the module into `initrd` and switching to the LTS kernel.
    *   *Challenge 3 (Boot Loops):* While the SD card eventually booted (verified IP 192.168.1.3), the transition to installing on the SSD failed or the system became unreachable after reboot. `kexec` from the bootstrap image also failed ("Resource busy").
3.  **Bootloader Gap:** The standard NixOS `generic-extlinux-compatible` bootloader does *not* populate the proprietary Raspberry Pi firmware (`start4.elf`, `u-boot.bin`) onto the SSD's EFI partition. This means even if we installed the OS, the SSD would not be bootable without the SD card acting as a crutch.

### The New Strategy: Direct Install
Instead of fighting the Pi's headless boot process, we will leverage a **Linux PC** to install NixOS directly onto the SSD.
*   **Pros:** Reliable internet, screen/keyboard (on PC), fast build speeds, easy debugging.
*   **Cons:** Requires physically moving the SSD to the PC (which we can do).

## Prerequisites
*   **Linux PC:** An x86_64 machine with Nix installed and `binfmt_misc` support for aarch64 (standard on NixOS).
*   **Samsung T5 SSD:** Plugged into the Linux PC.
*   **Dotfiles Repo:** Cloned on the Linux PC.

## Configuration Fixes (Already Applied)
We have already modified the `pi4` configuration to ensure it is self-sufficient:
1.  **Kernel:** Switched to `pkgs.linuxPackages` (LTS) for ZFS compatibility.
2.  **Firmware Script:** Added `system.activationScripts.rpi-firmware` to `hosts/pi4/hardware-configuration.nix`. This script automatically copies `start4.elf`, `u-boot-rpi4.bin`, and DTBs to `/boot` during activation. This makes the SSD independently bootable.
3.  **Disko:** Configured for ZFS on `usb-Samsung...`.

## Execution Plan (Run on Linux PC)

### 1. Identify the Drive
Ensure the SSD is detected and matches the ID in `hosts/pi4/disko.nix`.

```bash
ls -l /dev/disk/by-id/usb-Samsung_Portable_SSD_T5*
# Expected: usb-Samsung_Portable_SSD_T5_1234567A666E-0:0
```
*Note: If the ID differs (e.g. no `-0:0` suffix on this kernel), temporarily update `disko.nix` or symlink it.*

### 2. Partition & Format (Disko)
Run Disko to wipe the drive and create the ZFS pool `zroot`.

```bash
# From the dotfiles/configs/nixos directory
nix run github:nix-community/disko \
  --mode disko \
  --flake .#pi4
```
*This mounts the new filesystem at `/mnt`.*

### 3. Install NixOS
Install the system closure. Since the target is aarch64, your x86 PC uses QEMU emulation (binfmt) transparently.

```bash
# --no-root-passwd: We have SSH keys in common/user.nix
sudo nixos-install --flake .#pi4 --root /mnt --no-root-passwd
```

**Crucial Check:** The installation *should* run the activation script we added, populating `/mnt/boot` with firmware.

### 4. Verify Bootloader
Before unplugging, ensure the boot files exist on the SSD.

```bash
ls -F /mnt/boot/
# MUST contain: start4.elf, fixup4.dat, u-boot-rpi4.bin, config.txt
```

**If missing:**
Run the population logic manually (copy from `pkgs.raspberrypifw`):
```bash
# Enter a shell with the firmware packages available
nix shell nixpkgs#raspberrypifw nixpkgs#ubootRaspberryPi4_64bit -c bash

# Copy firmware
cp -r $(nix path-info nixpkgs#raspberrypifw)/share/raspberrypi/boot/* /mnt/boot/

# Copy U-Boot
cp $(nix path-info nixpkgs#ubootRaspberryPi4_64bit)/u-boot.bin /mnt/boot/u-boot-rpi4.bin

# Create config.txt
echo "kernel=u-boot-rpi4.bin" > /mnt/boot/config.txt
echo "arm_64bit=1" >> /mnt/boot/config.txt
echo "enable_uart=1" >> /mnt/boot/config.txt
```

### 5. Finalize
1.  `umount -R /mnt`
2.  `zpool export zroot`
3.  Unplug SSD.
4.  Plug SSD into Raspberry Pi 4.
5.  **Remove SD Card** (Force SSD boot).
6.  Power on.

The Pi should boot, load U-Boot from SSD, load NixOS from ZFS, and connect to WiFi using the credentials in `wifi.nix`.
