#!/usr/bin/env bash
set -e

# =======================================================================================
# Prepare SD card with Pi 3 UEFI firmware
# =======================================================================================
# Pi 3 cannot boot from USB directly - it needs an SD card with firmware.
# This creates an SD card that loads UEFI, which then boots NixOS from USB SSD.
#
# Usage: ./prepare-sdcard.sh /dev/sdX
# =======================================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEVICE="$1"

if [ -z "$DEVICE" ]; then
    echo "Usage: $0 /dev/sdX"
    echo "Example: $0 /dev/sdc"
    exit 1
fi

if [ "$EUID" -eq 0 ]; then
    echo "Run as normal user (not root). Script will sudo when needed."
    exit 1
fi

if [ ! -e "$DEVICE" ]; then
    echo "Device not found: $DEVICE"
    exit 1
fi

echo "WARNING: This will ERASE $DEVICE"
read -p "Proceed? (y/N) " -n 1 -r; echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

# Get firmware from Nix
echo "Getting UEFI firmware from Nix..."
FIRMWARE=$(nix build --no-link --print-out-paths "$FLAKE_DIR#nixosConfigurations.pi3.config.hardware.raspberry-pi.uefi.firmware")
echo "Firmware: $FIRMWARE"

# Create FAT32 partition
echo "Partitioning $DEVICE..."
sudo parted -s "$DEVICE" mklabel msdos
sudo parted -s "$DEVICE" mkpart primary fat32 1MiB 256MiB
sudo parted -s "$DEVICE" set 1 boot on

# Wait for partition to appear
sleep 2

# Format
PART="${DEVICE}1"
[ -e "${DEVICE}p1" ] && PART="${DEVICE}p1"  # nvme style
echo "Formatting $PART..."
sudo mkfs.vfat -F32 "$PART"

# Mount and copy firmware
echo "Copying UEFI firmware..."
sudo mount "$PART" /mnt
sudo cp -r "$FIRMWARE"/* /mnt/
sync
sudo umount /mnt

echo ""
echo "=============================================="
echo "SD card ready!"
echo ""
echo "Next steps:"
echo "  1. Insert SD card in Pi 3"
echo "  2. Connect SSD to Pi 3 USB port"
echo "  3. Connect HDMI and ethernet"
echo "  4. Power on"
echo ""
echo "You should see UEFI boot screen, then systemd-boot."
echo "=============================================="
