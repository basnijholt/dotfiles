# Raspberry Pi 4 Setup (pi4)

Headless Raspberry Pi 4 booting from **external SSD** (via USB) with **ZFS** root.

Uses **nixos-raspberrypi** flake for U-Boot boot with WiFi firmware included.

## Architecture

| Partition | Size | Type | Mount | Purpose |
|-----------|------|------|-------|---------|
| ESP | 512M | FAT32 | /boot | U-Boot, kernels |
| zfs | Rest | ZFS | / | Root filesystem with datasets |

## Prerequisites

**Hardware:**
- Raspberry Pi 4 (with updated EEPROM for USB boot)
- External SSD (Samsung T5 or similar)

**Build machine:**

Option A - Linux PC with emulation:
```nix
# configuration.nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
boot.supportedFilesystems = [ "zfs" ];
```

Option B - Mac with Apple Silicon (native aarch64 via Docker):
```bash
# Create persistent Nix store volume (avoids re-downloading)
docker volume create nix-cache

# Build inside container
docker run --rm -it \
  --platform linux/arm64 \
  -v $(pwd):/work \
  -v nix-cache:/nix \
  -w /work \
  nixos/nix \
  sh -c "
    mkdir -p /nix/var/nix/profiles/per-user/root
    nix --extra-experimental-features 'nix-command flakes' \
      build .#nixosConfigurations.pi4.config.system.build.toplevel \
      --show-trace
  "

# Copy closure to PC
docker run --rm \
  --platform linux/arm64 \
  -v $(pwd):/work \
  -v nix-cache:/nix \
  -w /work \
  nixos/nix \
  sh -c "nix --extra-experimental-features 'nix-command flakes' \
    copy --to ssh://pc ./result"
```

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
# Connect SSD to your build machine, then:
cd configs/nixos
./hosts/pi4/install-ssd.sh
```

The script will:
1. Partition the SSD (ESP + ZFS via disko)
2. Build the aarch64 system
3. Install NixOS
4. Set ZFS hostid

### 3. Deploy to Pi

1. Unplug SSD from build machine
2. Plug into Pi 4 (blue USB 3.0 port)
3. Remove any SD card
4. Power on

The Pi boots via U-Boot and connects to WiFi.

## Updating the System

Deploy changes remotely:

```bash
nixos-rebuild switch \
  --flake .#pi4 \
  --target-host root@pi4.local \
  --build-host root@pi4.local
```

Or build on Mac and deploy:

```bash
# On Mac
nix build .#nixosConfigurations.pi4.config.system.build.toplevel
nix copy --to ssh://pi4.local ./result
ssh root@pi4.local "nix-env -p /nix/var/nix/profiles/system --set $(readlink ./result) && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"
```

## Troubleshooting

### Pi doesn't connect to WiFi

1. Verify `wifi.nix` exists with correct credentials
2. Check that `brcmfmac` module is loaded: `lsmod | grep brcmfmac`
3. Check NetworkManager: `nmcli device status`

### Pi doesn't boot from SSD

1. Ensure Pi EEPROM supports USB boot (update via Raspberry Pi Imager if needed)
2. Check LED patterns:
   - No activity = boot firmware not found
   - Activity then stop = kernel/ZFS issue
3. Connect HDMI to see boot messages

### ZFS mount errors

If you see "cannot be mounted" errors, ensure `zfsutil` is NOT in any fileSystems options.
The hardware-configuration.nix has a warning comment about this.
