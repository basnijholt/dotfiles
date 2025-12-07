#!/usr/bin/env bash
set -e

# =======================================================================================
# Pi 4 UEFI SSD Installer (ZFS Root)
# =======================================================================================
# Installs NixOS onto a Samsung T5 SSD using UEFI boot (pftf/RPi4 firmware).
# Much simpler than U-Boot approach - standard NixOS aarch64 with systemd-boot.
#
# Prerequisites on your Linux PC:
#   boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
#   boot.supportedFilesystems = [ "zfs" ];
#
# Usage: ./hosts/pi4/install-ssd.sh (run from configs/nixos directory)
# =======================================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

FLAKE_ATTR="pi4"
DISK_ID="/dev/disk/by-id/usb-Samsung_Portable_SSD_T5_1234567A666E-0:0"
UEFI_VERSION="v1.38"
UEFI_URL="https://github.com/pftf/RPi4/releases/download/${UEFI_VERSION}/RPi4_UEFI_Firmware_${UEFI_VERSION}.zip"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Pre-flight Checks ---
log "Checking prerequisites..."

if [ "$EUID" -eq 0 ]; then
    error "Run as normal user (not root). Script will sudo when needed."
fi

if [ ! -e "$DISK_ID" ]; then
    error "Target disk not found: $DISK_ID\nPlug in the Samsung T5 SSD."
fi

if [ ! -f /proc/sys/fs/binfmt_misc/aarch64-linux ]; then
    error "aarch64 emulation not enabled. Add to config:\n  boot.binfmt.emulatedSystems = [ \"aarch64-linux\" ];"
fi

if ! grep -q zfs /proc/modules; then
    warn "ZFS module not loaded. Loading..."
    sudo modprobe zfs || error "Failed to load ZFS. Add to config:\n  boot.supportedFilesystems = [ \"zfs\" ];"
fi

log "Target: $DISK_ID"
echo -e "${RED}WARNING: ALL DATA ON THIS DISK WILL BE DESTROYED.${NC}"
read -p "Proceed? (y/N) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && error "Aborted."

# --- Step 1: Partition with Disko ---
log "Step 1: Partitioning with disko..."
sudo nix run github:nix-community/disko -- --mode disko "$SCRIPT_DIR/disko.nix"

# --- Step 2: Download and install UEFI firmware ---
log "Step 2: Installing pftf UEFI firmware (${UEFI_VERSION})..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
wget -q "$UEFI_URL" -O uefi.zip
unzip -q uefi.zip
rm -f README.md uefi.zip

# Copy UEFI firmware to ESP
sudo cp -r * /mnt/boot/
cd "$FLAKE_DIR"
rm -rf "$TEMP_DIR"
log "UEFI firmware installed to /mnt/boot"

# --- Step 3: Build the system ---
log "Step 3: Building NixOS system (aarch64)..."
nix build "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel" --no-link
SYSTEM_PATH=$(nix path-info "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel")
log "Built: $SYSTEM_PATH"

# --- Step 4: Install NixOS ---
log "Step 4: Installing NixOS to /mnt..."

# nixos-install copies the closure, installs systemd-boot, and runs activation
set +e
sudo nixos-install --system "$SYSTEM_PATH" --root /mnt --no-root-passwd 2>&1 | tee /tmp/nixos-install.log
INSTALL_EXIT=$?
set -e

if [ $INSTALL_EXIT -ne 0 ]; then
    warn "nixos-install exited with code $INSTALL_EXIT (may be OK for cross-arch)"
    warn "Checking if files were copied..."
fi

if [ ! -d "/mnt/nix/store" ] || [ -z "$(ls -A /mnt/nix/store 2>/dev/null)" ]; then
    error "Installation failed: /mnt/nix/store is empty"
fi
log "Nix store populated successfully."

# --- Step 5: Set ZFS bootfs property ---
log "Step 5: Setting ZFS bootfs property..."
sudo zpool set bootfs=zroot/root zroot
log "ZFS bootfs set to zroot/root"

# --- Step 6: Manual boot population (cross-arch fix) ---
log "Step 6: Populating boot partition manually (cross-arch workaround)..."

# nixos-install can't run aarch64 bootloader scripts on x86_64
# We need to manually install systemd-boot and create boot entries

# Find kernel and initrd from the system closure
KERNEL=$(find "$SYSTEM_PATH" -name 'Image' -type f 2>/dev/null | head -1)
INITRD=$(find "$SYSTEM_PATH" -name 'initrd' -type f 2>/dev/null | head -1)

if [ -z "$KERNEL" ] || [ -z "$INITRD" ]; then
    # Try alternative paths
    KERNEL=$(readlink -f "$SYSTEM_PATH/kernel")
    INITRD=$(readlink -f "$SYSTEM_PATH/initrd")
fi

if [ -z "$KERNEL" ] || [ ! -f "$KERNEL" ]; then
    error "Cannot find kernel in system closure"
fi
if [ -z "$INITRD" ] || [ ! -f "$INITRD" ]; then
    error "Cannot find initrd in system closure"
fi

log "Kernel: $KERNEL"
log "Initrd: $INITRD"

# Get init path from the system
INIT="$SYSTEM_PATH/init"

# Create EFI directory structure
sudo mkdir -p /mnt/boot/EFI/BOOT
sudo mkdir -p /mnt/boot/EFI/nixos
sudo mkdir -p /mnt/boot/EFI/systemd
sudo mkdir -p /mnt/boot/loader/entries

# Install systemd-boot EFI binary (aarch64 version)
# First check the already-installed target store (fast)
SYSTEMD_BOOT=$(find /mnt/nix/store -name 'systemd-bootaa64.efi' 2>/dev/null | head -1)
if [ -n "$SYSTEMD_BOOT" ] && [ -f "$SYSTEMD_BOOT" ]; then
    sudo cp "$SYSTEMD_BOOT" /mnt/boot/EFI/BOOT/BOOTAA64.EFI
    sudo cp "$SYSTEMD_BOOT" /mnt/boot/EFI/systemd/systemd-bootaa64.efi
    log "systemd-boot EFI binary installed (from target store)"
else
    # Fallback: build cross-compiled systemd (slow)
    warn "systemd-boot not in target store, building cross-compiled version..."
    SYSTEMD_BOOT=$(nix build nixpkgs#pkgsCross.aarch64-multiplatform.systemd --print-out-paths --no-link 2>/dev/null)/lib/systemd/boot/efi/systemd-bootaa64.efi
    if [ -f "$SYSTEMD_BOOT" ]; then
        sudo cp "$SYSTEMD_BOOT" /mnt/boot/EFI/BOOT/BOOTAA64.EFI
        sudo cp "$SYSTEMD_BOOT" /mnt/boot/EFI/systemd/systemd-bootaa64.efi
        log "systemd-boot EFI binary installed (cross-compiled)"
    else
        error "Cannot find systemd-boot EFI binary"
    fi
fi

# Create loader.conf
sudo tee /mnt/boot/loader/loader.conf > /dev/null <<EOF
timeout 3
default nixos.conf
editor yes
EOF
log "loader.conf created"

# Generate unique filenames based on hash
KERNEL_HASH=$(basename "$(dirname "$KERNEL")" | cut -c1-8)
KERNEL_NAME="nixos-kernel-${KERNEL_HASH}.efi"
INITRD_NAME="nixos-initrd-${KERNEL_HASH}.efi"

# Copy kernel and initrd to ESP
sudo cp "$KERNEL" "/mnt/boot/EFI/nixos/$KERNEL_NAME"
sudo cp "$INITRD" "/mnt/boot/EFI/nixos/$INITRD_NAME"
log "Kernel and initrd copied to ESP"

# Create boot entry
sudo tee /mnt/boot/loader/entries/nixos.conf > /dev/null <<EOF
title NixOS
linux /EFI/nixos/$KERNEL_NAME
initrd /EFI/nixos/$INITRD_NAME
options init=$INIT zfs=zroot/root
EOF
log "Boot entry created"

# --- Step 7: Verify boot files ---
log "Step 7: Verifying boot files..."
if ! sudo test -d /mnt/boot/EFI/systemd; then
    warn "systemd-boot not installed - may need manual installation"
fi
if ! sudo test -f /mnt/boot/RPI_EFI.fd; then
    error "UEFI firmware missing from /mnt/boot"
fi
if ! sudo test -f /mnt/boot/loader/entries/nixos.conf; then
    error "Boot entry missing from /mnt/boot/loader/entries/"
fi
log "Boot files verified."

# --- Step 8: Cleanup ---
log "Step 8: Cleanup..."
sudo umount -R /mnt || warn "Some mounts may need manual cleanup"
sudo zpool export zroot || warn "zpool export failed - may already be exported"

log "=============================================="
log "SUCCESS! Installation complete."
log ""
log "Next steps:"
log "  1. Unplug the Samsung T5 SSD"
log "  2. Connect to Raspberry Pi 4 (Blue USB 3.0 port)"
log "  3. Remove any SD card"
log "  4. Power on"
log ""
log "The Pi should boot via UEFI and connect to WiFi."
log "=============================================="
