#!/usr/bin/env bash
# Pi4 SSD Verify Script
# Verifies all boot components are correctly installed

set -e

LOG_FILE="/tmp/pi4-verify.log"
DISK_DEV="/dev/sda"

exec > >(tee "$LOG_FILE") 2>&1

echo "=========================================="
echo "Pi4 SSD Verify - $(date)"
echo "=========================================="
echo ""

# Mount partitions
echo "=== Mounting partitions ==="
sudo mkdir -p /mnt/pi4-boot /mnt/pi4-nix
sudo mount "${DISK_DEV}2" /mnt/pi4-boot 2>&1 || echo "Already mounted or failed"
sudo zpool import -N zroot 2>&1 || echo "Pool already imported"
sudo mount -t zfs zroot/nix /mnt/pi4-nix 2>&1 || echo "Already mounted or failed"
echo ""

# Extract system path from extlinux.conf
echo "=== Extracting system path from extlinux.conf ==="
SYSTEM_PATH=$(grep -oP 'init=\K[^ ]+' /mnt/pi4-boot/extlinux/extlinux.conf | sed 's|/init$||')
echo "System path in extlinux.conf: $SYSTEM_PATH"
echo ""

# Convert to local path
LOCAL_SYSTEM_PATH="/mnt/pi4-nix/store/$(basename $SYSTEM_PATH)"
echo "Looking for: $LOCAL_SYSTEM_PATH"
echo ""

# Check if system closure exists
echo "=== Verifying system closure exists ==="
if [ -d "$LOCAL_SYSTEM_PATH" ]; then
    echo "✅ System closure EXISTS"
    ls -la "$LOCAL_SYSTEM_PATH/" | head -10
else
    echo "❌ System closure MISSING!"
    echo ""
    echo "Available systems in store:"
    ls /mnt/pi4-nix/store/ | grep nixos-system | head -10
fi
echo ""

# Verify init script exists
echo "=== Verifying init script ==="
if [ -f "$LOCAL_SYSTEM_PATH/init" ]; then
    echo "✅ Init script exists"
    head -5 "$LOCAL_SYSTEM_PATH/init"
else
    echo "❌ Init script MISSING"
fi
echo ""

# Check kernel referenced in extlinux.conf
echo "=== Verifying kernel ==="
KERNEL_FILE=$(grep -oP 'LINUX \K[^ ]+' /mnt/pi4-boot/extlinux/extlinux.conf)
KERNEL_PATH="/mnt/pi4-boot/${KERNEL_FILE#../}"
if [ -f "$KERNEL_PATH" ]; then
    echo "✅ Kernel exists: $KERNEL_PATH"
    ls -lh "$KERNEL_PATH"
else
    echo "❌ Kernel MISSING: $KERNEL_PATH"
fi
echo ""

# Check initrd
echo "=== Verifying initrd ==="
INITRD_FILE=$(grep -oP 'INITRD \K[^ ]+' /mnt/pi4-boot/extlinux/extlinux.conf)
INITRD_PATH="/mnt/pi4-boot/${INITRD_FILE#../}"
if [ -f "$INITRD_PATH" ]; then
    echo "✅ Initrd exists: $INITRD_PATH"
    ls -lh "$INITRD_PATH"
else
    echo "❌ Initrd MISSING: $INITRD_PATH"
fi
echo ""

# Check FDT
echo "=== Verifying device tree ==="
FDT_FILE=$(grep -oP 'FDT \K[^ ]+' /mnt/pi4-boot/extlinux/extlinux.conf)
FDT_PATH="/mnt/pi4-boot/${FDT_FILE#../}"
if [ -f "$FDT_PATH" ]; then
    echo "✅ Device tree exists: $FDT_PATH"
    ls -lh "$FDT_PATH"
else
    echo "❌ Device tree MISSING: $FDT_PATH"
fi
echo ""

# Verify ZFS bootfs
echo "=== Verifying ZFS bootfs ==="
BOOTFS=$(sudo zpool get -H -o value bootfs zroot)
if [ "$BOOTFS" = "zroot/root" ]; then
    echo "✅ bootfs correctly set to zroot/root"
else
    echo "❌ bootfs is '$BOOTFS' (expected zroot/root)"
fi
sudo zpool get bootfs zroot
echo ""

# Check nix profiles
echo "=== Checking nix profiles ==="
sudo mkdir -p /mnt/pi4-root
sudo mount -t zfs zroot/root /mnt/pi4-root 2>&1 || echo "Already mounted"

PROFILES_DIR="/mnt/pi4-root/nix/var/nix/profiles"
if [ -d "$PROFILES_DIR" ]; then
    echo "Profiles directory exists:"
    ls -la "$PROFILES_DIR/"
else
    echo "Profiles directory missing, checking zroot/nix..."
    ls -la /mnt/pi4-nix/var/nix/profiles/ 2>/dev/null || echo "Not in zroot/nix either"
fi
echo ""

# Show final summary
echo "=========================================="
echo "=== SUMMARY ==="
echo "=========================================="
echo ""
echo "extlinux.conf:"
cat /mnt/pi4-boot/extlinux/extlinux.conf
echo ""

# Cleanup
echo "=== Cleanup ==="
sudo umount /mnt/pi4-root 2>/dev/null || true
sudo umount /mnt/pi4-nix 2>/dev/null || true
sudo umount /mnt/pi4-boot 2>/dev/null || true
sudo zpool export zroot 2>/dev/null || true
echo "Done."
echo ""

echo "=========================================="
echo "Log saved to: $LOG_FILE"
echo "=========================================="
