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
- MicroSD card (for bootstrap image)

**Build machine:**
- Linux PC or Mac (no emulation required for bootstrap image)

## Installation (Bootstrap SD Method)

This is the recommended method for headless setup.

### 1. Configure WiFi

Create `hosts/pi4/wifi.nix` with your credentials:

```nix
{
  networking.networkmanager.ensureProfiles.profiles = {
    "Home-WiFi" = {
      connection = {
        id = "Home-WiFi";
        type = "wifi";
        autoconnect = true;
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

### 2. Build Bootstrap SD Image

```bash
# Use path:. and --impure to include gitignored wifi.nix
nix build 'path:.#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage' --impure
```

> **Note:** `path:.` tells Nix to use all files (not just git-tracked), and `--impure` allows reading gitignored wifi.nix.

### 3. Flash to SD Card

```bash
# Find your SD card device
lsblk

# Flash the image (replace /dev/sdX with your device)
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 4. Boot and SSH

1. Insert SD card into Pi 4
2. Connect SSD to blue USB 3.0 port
3. Power on
4. Wait for WiFi to connect (~30 seconds)
5. SSH in:
   ```bash
   ssh nixos@pi-bootstrap.local  # password: nixos
   # or
   ssh root@pi-bootstrap.local   # uses your SSH key
   ```

### 5. Install to SSD

On the Pi (via SSH):

```bash
# Clone your dotfiles (or use the flake URL directly)
git clone https://github.com/basnijholt/dotfiles
cd dotfiles/configs/nixos

# Run the install script
./hosts/pi4/install-ssd.sh
```

The script will:
1. Partition the SSD (ESP + ZFS via disko)
2. Build the aarch64 system (using your local nix-cache)
3. Install NixOS
4. Set ZFS hostid

### 6. Boot from SSD

1. Power off Pi
2. Remove SD card
3. Power on - Pi boots from SSD via WiFi

## Alternative: Direct Install (requires build machine access to SSD)

If you can connect the SSD directly to your build machine:

```bash
# On build machine with binfmt emulation enabled:
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
boot.supportedFilesystems = [ "zfs" ];

# Connect SSD and run:
./hosts/pi4/install-ssd.sh
```

Then move SSD to Pi and boot.

## Updating the System

Deploy changes remotely:

```bash
nixos-rebuild switch \
  --flake .#pi4 \
  --target-host root@pi4.local \
  --build-host root@pi4.local
```

Or build locally and deploy:

```bash
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
