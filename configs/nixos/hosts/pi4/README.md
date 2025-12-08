# Raspberry Pi 4 Setup

Headless Pi 4 booting from external SSD with ZFS.

## Prerequisites

- Raspberry Pi 4 (EEPROM updated for USB boot)
- External SSD
- MicroSD card (temporary, for bootstrap)
- Build machine: Linux or Mac

## Installation

### 1. Create wifi.nix

Create `hosts/pi4/wifi.nix` (gitignored):

```nix
{
  networking.networkmanager.ensureProfiles.profiles."Home-WiFi" = {
    connection = { id = "Home-WiFi"; type = "wifi"; autoconnect = true; };
    wifi = { mode = "infrastructure"; ssid = "YOUR_SSID"; };
    wifi-security = { key-mgmt = "wpa-psk"; psk = "YOUR_PASSWORD"; };
    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}
```

### 2. Build and flash bootstrap SD

```bash
nix build 'path:.#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage' --impure
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. Boot and SSH in

1. Insert SD card and connect SSD to blue USB 3.0 port
2. Power on, wait ~30 seconds for WiFi
3. `ssh root@pi-bootstrap.local`

### 4. Install to SSD

```bash
git clone https://github.com/basnijholt/dotfiles
cd dotfiles/configs/nixos
./hosts/pi4/install-ssd.sh
```

### 5. Boot from SSD

1. Power off
2. Remove SD card
3. Power on — boots from SSD

## Updating

```bash
nixos-rebuild switch --flake .#pi4 --target-host root@pi4.local --build-host root@pi4.local
```

## Troubleshooting

- **No WiFi**: Check `wifi.nix` exists, verify with `nmcli device status`
- **Won't boot from SSD**: Update Pi EEPROM via Raspberry Pi Imager
- **ZFS errors**: Don't add `zfsutil` to fileSystems options
