# Raspberry Pi 4 Setup (pi4)

Headless Raspberry Pi 4 booting from **external SSD** (via USB) with **ZFS** root.

Uses **UEFI boot** via [pftf/RPi4](https://github.com/pftf/RPi4) firmware - standard NixOS aarch64, no special Pi flake needed.

## Architecture

| Partition | Size | Type | Mount | Purpose |
|-----------|------|------|-------|---------|
| ESP | 512M | FAT32 | /boot | UEFI firmware, systemd-boot, kernels |
| zfs | Rest | ZFS | / | Root filesystem with datasets |

## Prerequisites

**Hardware:**
- Raspberry Pi 4 (with updated EEPROM for USB boot)
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
1. Partition the SSD (ESP + ZFS via disko)
2. Download and install pftf UEFI firmware
3. Build the aarch64 system (using binfmt emulation)
4. Install NixOS with systemd-boot
5. Set ZFS bootfs property

### 3. Deploy to Pi

1. Unplug SSD from PC
2. Plug into Pi 4 (blue USB 3.0 port)
3. Remove any SD card
4. Power on

The Pi boots via UEFI and connects to WiFi.

## Updating the System

Deploy changes remotely:

```bash
nixos-rebuild switch \
  --flake .#pi4 \
  --target-host root@pi4.local \
  --build-host root@pi4.local
```

## UEFI Settings

On first boot, you may need to configure UEFI:
- Press **Esc** at the Raspberry Pi logo to enter setup
- Device Manager → Raspberry Pi Configuration → Advanced Settings
  - Disable "Limit RAM to 3 GB" if you have 4GB+ Pi

## Troubleshooting

### Pi doesn't connect to WiFi

1. Verify `wifi.nix` exists with correct credentials
2. Check that `brcmfmac` module is loaded: `lsmod | grep brcmfmac`
3. Check NetworkManager: `nmcli device status`

### Pi doesn't boot from SSD

1. Ensure Pi EEPROM supports USB boot (update via Raspberry Pi Imager if needed)
2. Check LED patterns:
   - No activity = UEFI firmware not found
   - Activity then stop = kernel/ZFS issue
3. Connect HDMI to see UEFI/boot messages
