# Raspberry Pi 4 Setup (pi4)

Headless Raspberry Pi 4 booting from **external SSD** (via USB) with **ZFS** root.

Uses the [nixos-raspberrypi](https://github.com/nvmd/nixos-raspberrypi) flake for kernel, firmware, and bootloader support.

## Architecture

| Partition | Size | Type | Mount | Purpose |
|-----------|------|------|-------|---------|
| firmware | 256M | FAT32 | /boot/firmware | RPi firmware, U-Boot, config.txt |
| boot | 512M | ext4 | /boot | Kernel, initrd, extlinux.conf |
| zfs | Rest | ZFS | / | Root filesystem with datasets |

## Prerequisites

**Hardware:**
- Raspberry Pi 4
- External SSD (Samsung T5 or similar)

**Build machine (Linux PC):**
```nix
# configuration.nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
boot.supportedFilesystems = [ "zfs" ];
```
Reboot after adding these.

## Installation

### 1. Configure WiFi

Create `hosts/pi4/wifi.nix` with your credentials:

```nix
{
  networking.networkmanager.ensureProfiles.profiles = {
    "Home-WiFi" = {
      connection = {
        id = "Home-WiFi";
        type = "wifi";
      };
      wifi = {
        mode = "infrastructure";
        ssid = "YOUR_SSID";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "YOUR_PASSWORD";
      };
      ipv4 = { method = "auto"; };
      ipv6 = { method = "auto"; };
    };
  };
}
```

### 2. Run the Install Script

```bash
# Connect SSD to your Linux PC, then:
cd configs/nixos
./hosts/pi4/install-ssd.sh
```

The script will:
1. Partition the SSD (disko)
2. Build the aarch64 system (using binfmt emulation)
3. Install NixOS to the SSD
4. Populate the bootloader (firmware + extlinux)

### 3. Deploy to Pi

1. Unplug SSD from PC
2. Plug into Pi 4 (blue USB 3.0 port)
3. Remove any SD card
4. Power on

The Pi boots directly from SSD and connects to WiFi.

## Alternative: Build on Mac, Flash on Linux

For faster builds, use native ARM on Apple Silicon Mac, then flash on Linux.

### Step 1: Build on Mac (Docker)

```bash
# Start Docker container with nix (from configs/nixos directory)
docker run --rm -it \
  --platform linux/arm64 \
  --dns 192.168.1.66 \
  -v $(pwd):/work \
  -v nix-pi4-cache:/nix \
  -v ~/.ssh:/root/.ssh:ro \
  -w /work \
  nixos/nix bash

# Inside container:
nix --extra-experimental-features 'nix-command flakes' \
  build .#nixosConfigurations.pi4.config.system.build.toplevel \
  --substituters 'https://nixos-raspberrypi.cachix.org https://cache.nixos.org' \
  --trusted-public-keys 'nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY='
```

### Step 2: Copy to Linux PC

```bash
# Inside Docker container - copy to Linux PC via SSH
nix --extra-experimental-features 'nix-command flakes' copy --to 'ssh://basnijholt@pc' --accept-flake-config .#nixosConfigurations.pi4.config.system.build.toplevel
```

### Step 3: Flash on Linux

```bash
# On Linux PC with SSD attached
cd configs/nixos
./hosts/pi4/install-ssd.sh
```

## Updating the System

Deploy changes remotely:

```bash
nixos-rebuild switch \
  --flake .#pi4 \
  --target-host root@pi4.local \
  --build-host root@pi4.local
```

## Troubleshooting

### Pi doesn't connect to WiFi

1. Verify `wifi.nix` exists with correct credentials
2. Check that `brcmfmac` module is loaded: `lsmod | grep brcmfmac`
3. Check NetworkManager: `nmcli device status`

### Pi doesn't boot from SSD

1. Check LED patterns:
   - 4 blinks = kernel not found
   - 7 blinks = kernel image bad
2. Connect HDMI to see boot messages
3. Verify U-Boot is loading: check for `u-boot-rpi-arm64.bin` in `/boot/firmware`
