# Raspberry Pi 4 Setup (pi4)

This configuration sets up a **headless Raspberry Pi 4** booting from an **external SSD** (via USB) using **ZFS**.

## Architecture
*   **Initial State:** Raspberry Pi 4 running existing Linux (Debian/RaspiOS 64-bit) on SD Card.
*   **Target State:** NixOS ZFS on external SSD (`/dev/disk/by-id/usb-Samsung_Portable_SSD_T5_...`).
*   **Network:** Ethernet (for Install) -> WiFi (Final System).

## Prerequisites
1.  Raspberry Pi 4 with **64-bit** OS running (check with `uname -m` -> `aarch64`).
2.  External SSD (target drive) connected.
3.  **Ethernet Cable** connected.

## Installation Steps

### 1. Configure WiFi (For Final System)
You have already created `configs/nixos/hosts/pi4/wifi.nix`. This file is locally imported by the configuration so the final system will have WiFi credentials baked in.

### 2. Prepare the Pi
1.  Plug in the Ethernet cable.
2.  Power on the Pi.
3.  SSH into the existing Debian system to verify access and architecture:
    ```bash
    ssh user@<PI_IP_ADDRESS>
uname -m  # Must be aarch64
    ```

### 3. Install to SSD using Nix-Anywhere
Run this command from your Mac. `nix-anywhere` will SSH in, load a NixOS installer into RAM, format the SSD, and install.

```bash
# Replace <PI_IP_ADDRESS> with the actual IP
# Replace <USER> with the username on the existing Debian system (e.g. 'pi' or 'dietpi')
nix --extra-experimental-features 'nix-command flakes' run --impure github:nix-community/nixos-anywhere -- \
  --flake .#pi4 \
  --build-on-remote \
  <USER>@<PI_IP_ADDRESS>
```

> **Note:**
> *   `--impure`: Required to read your local `wifi.nix`.
> *   `--build-on-remote`: Builds the system closure on the Pi itself (avoids cross-compilation issues on Mac, though Mac can usually build aarch64 linux via remote builders or emulation if configured. If this fails, try removing it).

### 4. Finish
1.  When the command finishes, the Pi will reboot.
2.  It will boot from the SSD.
3.  You can now unplug the Ethernet cable; it should switch to WiFi automatically using the credentials in `wifi.nix`.
