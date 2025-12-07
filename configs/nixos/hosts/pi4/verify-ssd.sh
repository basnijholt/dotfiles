#!/usr/bin/env bash
# Pi4 SSD Verify Script (UEFI)
# Verifies all boot components are correctly installed

set -e

LOG_FILE="/tmp/pi4-verify.log"
DISK_DEV="/dev/sda"

# Ensure log is readable by all
rm -f "$LOG_FILE" 2>/dev/null || sudo rm -f "$LOG_FILE" 2>/dev/null || true
exec > >(tee "$LOG_FILE") 2>&1

echo "=========================================="
echo "Pi4 SSD Verify (UEFI) - $(date)"
echo "=========================================="
echo ""

# --- Partition Layout ---
echo "=== PARTITION LAYOUT ==="
lsblk -f "$DISK_DEV" 2>/dev/null || lsblk -f
echo ""

# --- Mount partitions ---
echo "=== MOUNTING PARTITIONS ==="
sudo mkdir -p /mnt/pi4-boot /mnt/pi4-nix
sudo mount "${DISK_DEV}1" /mnt/pi4-boot 2>&1 || echo "Already mounted or failed"
sudo zpool import -N zroot 2>&1 || echo "Pool already imported"
sudo mount -t zfs zroot/nix /mnt/pi4-nix 2>&1 || echo "Already mounted or failed"
echo ""

# --- ESP Partition (UEFI + systemd-boot) ---
echo "=========================================="
echo "=== ESP PARTITION (/boot) ==="
echo "=========================================="
echo ""

echo "=== Directory listing ==="
ls -la /mnt/pi4-boot/ 2>&1 || echo "Cannot list"
echo ""

echo "=== UEFI firmware (RPI_EFI.fd) ==="
if [ -f /mnt/pi4-boot/RPI_EFI.fd ]; then
    echo "✅ UEFI firmware present"
    ls -la /mnt/pi4-boot/RPI_EFI.fd
else
    echo "❌ UEFI firmware MISSING"
fi
echo ""

echo "=== config.txt ==="
cat /mnt/pi4-boot/config.txt 2>&1 || echo "config.txt not found"
echo ""

echo "=== systemd-boot installed? ==="
if [ -f /mnt/pi4-boot/EFI/BOOT/BOOTAA64.EFI ]; then
    echo "✅ BOOTAA64.EFI present"
    ls -la /mnt/pi4-boot/EFI/BOOT/BOOTAA64.EFI
else
    echo "❌ BOOTAA64.EFI MISSING"
fi
if [ -d /mnt/pi4-boot/EFI/systemd ]; then
    echo "✅ systemd-boot directory exists"
    ls -la /mnt/pi4-boot/EFI/systemd/
else
    echo "❌ systemd-boot directory MISSING"
fi
echo ""

echo "=== loader.conf ==="
if [ -f /mnt/pi4-boot/loader/loader.conf ]; then
    echo "✅ loader.conf present"
    cat /mnt/pi4-boot/loader/loader.conf
else
    echo "❌ loader.conf MISSING"
fi
echo ""

echo "=== Boot entries ==="
ls -la /mnt/pi4-boot/loader/entries/ 2>&1 || echo "No boot entries"
if [ -f /mnt/pi4-boot/loader/entries/nixos.conf ]; then
    echo ""
    echo "=== nixos.conf contents ==="
    cat /mnt/pi4-boot/loader/entries/nixos.conf
fi
echo ""

echo "=== NixOS kernels ==="
ls -la /mnt/pi4-boot/EFI/nixos/ 2>&1 | head -20 || echo "No NixOS kernels"
echo ""

# --- ZFS Pool ---
echo "=========================================="
echo "=== ZFS POOL ==="
echo "=========================================="
echo ""

echo "=== Pool status ==="
sudo zpool status zroot 2>&1 || echo "Cannot get pool status"
echo ""

echo "=== Verifying ZFS bootfs ==="
BOOTFS=$(sudo zpool get -H -o value bootfs zroot 2>/dev/null)
if [ "$BOOTFS" = "zroot/root" ]; then
    echo "✅ bootfs correctly set to zroot/root"
else
    echo "❌ bootfs is '$BOOTFS' (expected zroot/root)"
fi
sudo zpool get bootfs zroot
echo ""

echo "=== ZFS datasets ==="
sudo zfs list -r zroot 2>&1 || echo "Cannot list datasets"
echo ""

# --- Nix Store ---
echo "=========================================="
echo "=== NIX STORE ==="
echo "=========================================="
echo ""

echo "=== Package count ==="
PKGCOUNT=$(ls /mnt/pi4-nix/store/ 2>/dev/null | wc -l)
echo "Packages in store: $PKGCOUNT"
echo ""

echo "=== System closure ==="
ls /mnt/pi4-nix/store/ | grep nixos-system-pi4 | head -3 || echo "No system found"
echo ""

echo "=== Nix profiles ==="
ls -la /mnt/pi4-nix/var/nix/profiles/ 2>/dev/null || echo "No profiles"
echo ""

# --- Cleanup ---
echo "=========================================="
echo "=== CLEANUP ==="
echo "=========================================="
sudo umount /mnt/pi4-nix 2>/dev/null || true
sudo umount /mnt/pi4-boot 2>/dev/null || true
sudo zpool export zroot 2>/dev/null || true
echo "Done."
echo ""

echo "=========================================="
echo "Log saved to: $LOG_FILE"
echo "=========================================="
