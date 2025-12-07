#!/usr/bin/env bash
set -e

# Quick fix to populate boot partition on already-installed SSD
# Run this if nixos-install didn't install systemd-boot (cross-arch issue)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

if [ "$EUID" -ne 0 ]; then
    error "Run with sudo: sudo ./hosts/pi4/fix-boot.sh"
fi

DISK_DEV="/dev/sda"

log "Mounting partitions..."
mkdir -p /mnt/pi4-boot /mnt/pi4-root
mount "${DISK_DEV}1" /mnt/pi4-boot
zpool import -N zroot 2>/dev/null || true
mount -t zfs zroot/root /mnt/pi4-root
mount -t zfs zroot/nix /mnt/pi4-root/nix

# Find the system closure
SYSTEM_PATH=$(readlink -f /mnt/pi4-root/nix/var/nix/profiles/system)
log "System: $SYSTEM_PATH"

# Find kernel and initrd
KERNEL=$(readlink -f "$SYSTEM_PATH/kernel")
INITRD=$(readlink -f "$SYSTEM_PATH/initrd")

if [ ! -f "$KERNEL" ]; then
    error "Cannot find kernel at $KERNEL"
fi
if [ ! -f "$INITRD" ]; then
    error "Cannot find initrd at $INITRD"
fi

log "Kernel: $KERNEL"
log "Initrd: $INITRD"

# Create EFI directory structure
mkdir -p /mnt/pi4-boot/EFI/BOOT
mkdir -p /mnt/pi4-boot/EFI/nixos
mkdir -p /mnt/pi4-boot/EFI/systemd
mkdir -p /mnt/pi4-boot/loader/entries

# Find systemd-boot EFI binary from the installed system
SYSTEMD_BOOT=$(find /mnt/pi4-root/nix/store -name 'systemd-bootaa64.efi' 2>/dev/null | head -1)
if [ -z "$SYSTEMD_BOOT" ]; then
    error "Cannot find systemd-bootaa64.efi in nix store"
fi

log "Installing systemd-boot from: $SYSTEMD_BOOT"
cp "$SYSTEMD_BOOT" /mnt/pi4-boot/EFI/BOOT/BOOTAA64.EFI
cp "$SYSTEMD_BOOT" /mnt/pi4-boot/EFI/systemd/systemd-bootaa64.efi

# Create loader.conf
cat > /mnt/pi4-boot/loader/loader.conf <<EOF
timeout 3
default nixos.conf
editor yes
EOF
log "loader.conf created"

# Generate filenames
KERNEL_HASH=$(basename "$(dirname "$KERNEL")" | cut -c1-8)
KERNEL_NAME="nixos-kernel-${KERNEL_HASH}.efi"
INITRD_NAME="nixos-initrd-${KERNEL_HASH}.efi"

# Copy kernel and initrd
cp "$KERNEL" "/mnt/pi4-boot/EFI/nixos/$KERNEL_NAME"
cp "$INITRD" "/mnt/pi4-boot/EFI/nixos/$INITRD_NAME"
log "Kernel and initrd copied"

# Create boot entry (root=ZFS= is required for NixOS stage-1 to find the pool)
cat > /mnt/pi4-boot/loader/entries/nixos.conf <<EOF
title NixOS
linux /EFI/nixos/$KERNEL_NAME
initrd /EFI/nixos/$INITRD_NAME
options init=$SYSTEM_PATH/init root=ZFS=zroot/root
EOF
log "Boot entry created"

# Verify
log "=== Boot partition contents ==="
ls -la /mnt/pi4-boot/
ls -la /mnt/pi4-boot/EFI/
ls -la /mnt/pi4-boot/EFI/nixos/
cat /mnt/pi4-boot/loader/entries/nixos.conf

# Cleanup
log "Cleaning up..."
umount /mnt/pi4-root/nix
umount /mnt/pi4-root
umount /mnt/pi4-boot
zpool export zroot

log "Done! Boot partition is now populated."
log "Connect SSD to Pi and power on."
