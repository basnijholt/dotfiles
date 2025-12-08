# Raspberry Pi 3 Setup

Pi 3 with SSD root filesystem. SD card provides boot files, SSD provides ZFS root.

## Prerequisites

- Raspberry Pi 3
- External SSD
- MicroSD card (permanent, for boot files)
- Build machine: Linux or Mac

## Installation

### 1. Create wifi.nix

Create `hosts/pi4/wifi.nix` (shared with Pi 4, gitignored):

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
nix build 'path:.#nixosConfigurations.pi3-bootstrap.config.system.build.sdImage' --impure
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. Boot and SSH in

1. Insert SD card and connect SSD
2. Power on, wait ~30 seconds for WiFi
3. `ssh root@pi-bootstrap.local`

### 4. Install to SSD

```bash
git clone https://github.com/basnijholt/dotfiles
cd dotfiles/configs/nixos
# from other machine: `scp hosts/pi4/wifi.nix root@pi-bootstrap.local:dotfiles/configs/nixos/hosts/pi4/wifi.nix`
./hosts/pi3/install-ssd.sh
```

### 5. Copy boot files to SD card

The Pi 3 boot ROM can only read from SD, so copy boot files from SSD:

```bash
sudo mount /dev/mmcblk0p1 /mnt
sudo cp -r /mnt/boot/* /mnt/   # Copy from SSD ESP to SD
sudo umount /mnt
```

### 6. Reboot

System boots from SD card but runs from SSD.

## Updating

```bash
nixos-rebuild switch --flake .#pi3 --target-host root@pi3.local --build-host root@pi3.local
```

After kernel updates, repeat step 5 to update SD card boot files.

## Troubleshooting

- **No WiFi**: Check `hosts/pi4/wifi.nix` exists
- **Won't boot**: Ensure SD card has `bootcode.bin`, `start.elf`, `config.txt`
- **ZFS errors**: Don't add `zfsutil` to fileSystems options
