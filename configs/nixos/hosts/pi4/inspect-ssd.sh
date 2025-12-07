#!/usr/bin/env bash
# Pi4 SSD Diagnostic Script
# Inspects the SSD partitions and outputs everything to a log file

set -e

LOG_FILE="/tmp/pi4-ssd-inspect.log"
DISK_DEV="/dev/sda"

exec > >(tee "$LOG_FILE") 2>&1

echo "=========================================="
echo "Pi4 SSD Diagnostic - $(date)"
echo "=========================================="
echo ""

# --- Partition Layout ---
echo "=== PARTITION LAYOUT ==="
lsblk -f "$DISK_DEV" 2>/dev/null || lsblk -f
echo ""

echo "=== PARTITION TABLE ==="
sudo fdisk -l "$DISK_DEV" 2>/dev/null | head -30
echo ""

# --- Mount partitions ---
echo "=== MOUNTING PARTITIONS ==="
sudo mkdir -p /mnt/pi4-firmware /mnt/pi4-boot
sudo mount "${DISK_DEV}1" /mnt/pi4-firmware 2>&1 || echo "Failed to mount firmware partition"
sudo mount "${DISK_DEV}2" /mnt/pi4-boot 2>&1 || echo "Failed to mount boot partition"
echo "Mounted."
echo ""

# --- Firmware Partition (FAT) ---
echo "=========================================="
echo "=== FIRMWARE PARTITION (/boot/firmware) ==="
echo "=========================================="
echo ""

echo "=== Directory listing ==="
ls -la /mnt/pi4-firmware/ 2>&1 || echo "Cannot list"
echo ""

echo "=== config.txt ==="
cat /mnt/pi4-firmware/config.txt 2>&1 || echo "config.txt not found"
echo ""

echo "=== cmdline.txt (if exists) ==="
cat /mnt/pi4-firmware/cmdline.txt 2>&1 || echo "cmdline.txt not found"
echo ""

echo "=== U-Boot binary present? ==="
ls -la /mnt/pi4-firmware/*.bin 2>&1 || echo "No .bin files"
echo ""

echo "=== Firmware files (start*.elf, fixup*.dat) ==="
ls -la /mnt/pi4-firmware/start*.elf /mnt/pi4-firmware/fixup*.dat 2>&1 || echo "Missing firmware files"
echo ""

echo "=== DTB files in firmware partition ==="
ls -la /mnt/pi4-firmware/*.dtb 2>&1 || echo "No .dtb files in firmware"
ls -la /mnt/pi4-firmware/overlays/ 2>&1 | head -20 || echo "No overlays directory"
echo ""

# --- Boot Partition (ext4) ---
echo "=========================================="
echo "=== BOOT PARTITION (/boot) ==="
echo "=========================================="
echo ""

echo "=== Directory listing ==="
ls -la /mnt/pi4-boot/ 2>&1 || echo "Cannot list"
echo ""

echo "=== extlinux/extlinux.conf ==="
cat /mnt/pi4-boot/extlinux/extlinux.conf 2>&1 || echo "extlinux.conf not found"
echo ""

echo "=== nixos directory ==="
ls -la /mnt/pi4-boot/nixos/ 2>&1 || echo "No nixos directory"
echo ""

echo "=== Device trees in boot partition ==="
DTBS_DIR=$(ls -d /mnt/pi4-boot/nixos/*-dtbs 2>/dev/null | head -1)
if [ -n "$DTBS_DIR" ]; then
    echo "DTBs directory: $DTBS_DIR"
    ls -la "$DTBS_DIR/broadcom/" 2>&1 | grep bcm2711 || echo "No bcm2711 dtbs"
else
    echo "No dtbs directory found"
fi
echo ""

echo "=== Kernel and initrd files ==="
ls -lah /mnt/pi4-boot/nixos/*-Image /mnt/pi4-boot/nixos/*-initrd 2>&1 || echo "Missing kernel/initrd"
echo ""

# --- ZFS Pool ---
echo "=========================================="
echo "=== ZFS POOL ==="
echo "=========================================="
echo ""

echo "=== Available pools ==="
sudo zpool import 2>&1 || echo "No pools found"
echo ""

echo "=== Importing zroot (if not imported) ==="
sudo zpool import -N zroot 2>&1 || echo "Pool already imported or not found"
echo ""

echo "=== Pool status ==="
sudo zpool status zroot 2>&1 || echo "Cannot get pool status"
echo ""

echo "=== Pool properties ==="
sudo zpool get bootfs,cachefile zroot 2>&1 || echo "Cannot get pool properties"
echo ""

echo "=== ZFS datasets ==="
sudo zfs list -r zroot 2>&1 || echo "Cannot list datasets"
echo ""

echo "=== Mounting zroot/root temporarily ==="
sudo mkdir -p /mnt/pi4-root
sudo mount -t zfs zroot/root /mnt/pi4-root 2>&1 || echo "Failed to mount zroot/root"
echo ""

echo "=== Root filesystem contents ==="
ls -la /mnt/pi4-root/ 2>&1 || echo "Cannot list root"
echo ""

echo "=== /etc/machine-id ==="
cat /mnt/pi4-root/etc/machine-id 2>&1 || echo "No machine-id"
echo ""

echo "=== Nix profiles ==="
ls -la /mnt/pi4-root/nix/var/nix/profiles/ 2>&1 || echo "No profiles"
echo ""

echo "=== Current system link ==="
ls -la /mnt/pi4-root/run/current-system 2>&1 || echo "No current-system (expected before first boot)"
echo ""

echo "=== Mounting zroot/nix ==="
sudo mkdir -p /mnt/pi4-nix
sudo mount -t zfs zroot/nix /mnt/pi4-nix 2>&1 || echo "Failed to mount zroot/nix"
echo ""

echo "=== Nix store package count ==="
ls /mnt/pi4-nix/store/ 2>/dev/null | wc -l || echo "Cannot count"
echo ""

echo "=== System closure exists? ==="
ls -la /mnt/pi4-nix/store/vad1s1da031dl0wq87fbj72aqkxqiz2x-nixos-system-pi4-25.05.20251125.59714df/ 2>&1 | head -10 || echo "System closure not found"
echo ""

# --- Cleanup ---
echo "=========================================="
echo "=== CLEANUP ==="
echo "=========================================="
sudo umount /mnt/pi4-root 2>/dev/null || true
sudo umount /mnt/pi4-nix 2>/dev/null || true
sudo umount /mnt/pi4-firmware 2>/dev/null || true
sudo umount /mnt/pi4-boot 2>/dev/null || true
sudo zpool export zroot 2>/dev/null || true
echo "Cleanup complete."
echo ""

echo "=========================================="
echo "Log saved to: $LOG_FILE"
echo "=========================================="
