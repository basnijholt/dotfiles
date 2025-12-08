# Raspberry Pi 3 Setup (pi3)

Debug host for Pi boot issues with **HDMI/ethernet** for troubleshooting.

Currently boots from **SD card** (boot firmware) + **external SSD** (ZFS root via USB).

Uses **nixos-raspberrypi** flake for U-Boot boot with WiFi firmware included.

## Architecture

**Important:** Pi 3 cannot boot directly from USB without first enabling USB boot mode.

| Device | Partition | Type | Purpose |
|--------|-----------|------|---------|
| SD Card | FAT32 | /boot | Boot firmware, U-Boot, kernel, initrd |
| SSD | ESP (512M) | FAT32 | Copy of boot files (source for SD card) |
| SSD | zfs (rest) | ZFS | Root filesystem with datasets |

Boot chain: `SD card → bootcode.bin → start.elf → U-Boot → kernel → ZFS root on USB`

## Prerequisites

**Hardware:**
- Raspberry Pi 3
- MicroSD card (any size, only ~100MB used for boot)
- External SSD (Samsung T5 or similar) - for SSD setup
- HDMI cable + monitor (for debugging)

**Build machine:**
- Linux PC or Mac (no emulation required for bootstrap image)

## Installation (Bootstrap SD Method)

This is the recommended method - works headless via WiFi.

### 1. Configure WiFi

WiFi credentials are shared with Pi 4. Create `hosts/pi4/wifi.nix`:

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
nix build .#nixosConfigurations.pi3-bootstrap.config.system.build.sdImage
```

### 3. Flash to SD Card

```bash
# Find your SD card device
lsblk

# Flash the image (replace /dev/sdX with your device)
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 4. Boot and SSH

1. Insert SD card into Pi 3
2. Connect SSD to USB port (if using SSD setup)
3. Connect HDMI + ethernet (optional, for debugging)
4. Power on
5. Wait for WiFi to connect (~30 seconds)
6. SSH in:
   ```bash
   ssh nixos@pi-bootstrap.local  # password: nixos
   # or
   ssh root@pi-bootstrap.local   # uses your SSH key
   ```

### 5a. Install to SSD (current setup)

On the Pi (via SSH):

```bash
# Clone your dotfiles
git clone https://github.com/basnijholt/dotfiles
cd dotfiles/configs/nixos

# Run the install script
./hosts/pi3/install-ssd.sh
```

After install:
1. Copy boot files from SSD to SD card (see "Copy Boot Files" section below)
2. Reboot - system runs from SSD with SD card providing boot files

### 5b. Run from SD Card Only (alternative)

For a simpler SD-only setup without external SSD:

```bash
# After SSH'ing in, switch to a SD-compatible config
sudo nixos-rebuild switch --flake github:basnijholt/dotfiles?dir=configs/nixos#pi3
```

Note: This requires a `pi3` config that doesn't use ZFS/disko.

## Copy Boot Files to SD Card

After installing to SSD, copy boot files to SD card:

**On the Pi:**
```bash
# Mount SD card boot partition
sudo mount /dev/mmcblk0p1 /mnt/sd

# Copy boot files from SSD
sudo cp -r /boot/* /mnt/sd/
sudo umount /mnt/sd
```

**On Mac (with SD card reader):**
```bash
# Mount SSD ESP and SD card, then:
cp -r /Volumes/ESP/* /Volumes/SDCARD/
```

## Enabling USB Boot Mode (Optional)

To boot directly from USB without SD card:

```bash
# On the running Pi:
echo program_usb_boot_mode=1 | sudo tee -a /boot/config.txt
sudo reboot
```

After this one-time change, Pi 3 can boot from USB without an SD card.

## Updating the System

Deploy changes remotely:

```bash
nixos-rebuild switch --flake .#pi3 --target-host root@pi3.local
```

After kernel/initrd updates, also update the SD card boot files.

## Troubleshooting

### "No bootable device found"

- Ensure SD card has boot files (not just SSD)
- Check SD card is FAT32 formatted
- Verify `bootcode.bin`, `start.elf`, `config.txt` exist on SD card

### Pi boots but no network

1. Check ethernet cable connection
2. Verify WiFi credentials in `wifi.nix`
3. Check NetworkManager: `nmcli device status`

### ZFS mount errors

If you see "cannot be mounted" errors, ensure `zfsutil` is NOT in any fileSystems options.
