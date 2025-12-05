# Raspberry Pi 4 Setup (pi4)

This configuration sets up a **headless Raspberry Pi 4** booting from an **external SSD** (via USB) using **ZFS**.

## Architecture
*   **Boot:** SD Card (Bootstrap image).
*   **Root Filesystem:** ZFS on external SSD (`/dev/disk/by-id/usb-Samsung_Portable_SSD_T5_...`).
*   **Network:** Ethernet (for Install) -> WiFi (Final System).

## Prerequisites
1.  Raspberry Pi 4.
2.  MicroSD Card.
3.  External SSD (target drive).
4.  Ethernet Cable.

## Installation Steps

### 1. Configure WiFi (For Final System)
Ensure `configs/nixos/hosts/pi4/wifi.nix` exists with your real credentials. This ensures the final system can connect wirelessly.

### 2. Build Bootstrap SD Image
The existing DietPi/Debian kernel lacks `kexec` support, so we must boot a proper NixOS installer from the SD card.

```bash
# Build the image
nix build .#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage --impure
```

The output image will be in `result/sd-image/nixos-sd-image-*-aarch64-linux.img`.

### 3. Flash & Boot
1.  Flash the image to your MicroSD card (using `dd` or BalenaEtcher).
2.  Insert the SD card and the external SSD into the Pi.
3.  **Connect Ethernet.**
4.  Power on.
5.  Wait for it to boot and acquire an IP (check your router).

### 4. Install to SSD
Run `nixos-anywhere` from your Mac. It will connect to the running NixOS bootstrap system (user `root`, no password, or your SSH key if present), format the SSD, and install the final system.

```bash
# Replace <PI_IP_ADDRESS> with the actual IP
nix --extra-experimental-features 'nix-command flakes' run --impure github:nix-community/nixos-anywhere -- \
  --flake .#pi4 \
  --build-on remote \
  root@<PI_IP_ADDRESS>
```

### 5. Finish
1.  The Pi will reboot into the new ZFS system on the SSD.
2.  Unplug Ethernet.
3.  It should connect to WiFi automatically.

```