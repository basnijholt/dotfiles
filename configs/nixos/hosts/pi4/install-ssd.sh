#!/usr/bin/env bash
set -e

# =======================================================================================
# Pi 4 UEFI SSD Installer (Declarative)
# =======================================================================================
# Installs NixOS onto a Samsung T5 SSD using UEFI boot.
# UEFI firmware is declared in Nix - no manual downloads!
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

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Pre-flight Checks ---
log "Checking prerequisites..."

[ "$EUID" -eq 0 ] && error "Run as normal user (not root). Script will sudo when needed."
[ ! -e "$DISK_ID" ] && error "Target disk not found: $DISK_ID\nPlug in the Samsung T5 SSD."
[ ! -f /proc/sys/fs/binfmt_misc/aarch64-linux ] && error "aarch64 emulation not enabled. Add:\n  boot.binfmt.emulatedSystems = [ \"aarch64-linux\" ];"

if ! grep -q zfs /proc/modules; then
    warn "ZFS module not loaded. Loading..."
    sudo modprobe zfs || error "Failed to load ZFS. Add:\n  boot.supportedFilesystems = [ \"zfs\" ];"
fi

log "Target: $DISK_ID"
echo -e "${RED}WARNING: ALL DATA ON THIS DISK WILL BE DESTROYED.${NC}"
read -p "Proceed? (y/N) " -n 1 -r; echo
[[ ! $REPLY =~ ^[Yy]$ ]] && error "Aborted."

# --- Step 1: Partition with Disko ---
log "Step 1: Partitioning with disko..."
sudo nix run github:nix-community/disko -- --mode disko "$SCRIPT_DIR/disko.nix"

# --- Step 2: Build the system ---
log "Step 2: Building NixOS system..."
nix build "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel" --no-link
SYSTEM_PATH=$(nix path-info "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel")
log "Built: $SYSTEM_PATH"

# --- Step 3: Get UEFI firmware from Nix config ---
log "Step 3: Getting UEFI firmware from Nix..."
UEFI_FIRMWARE=$(nix build --no-link --print-out-paths "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.hardware.raspberry-pi.uefi.firmware")
[ -z "$UEFI_FIRMWARE" ] || [ ! -d "$UEFI_FIRMWARE" ] && error "Cannot get UEFI firmware from Nix"
log "UEFI firmware: $UEFI_FIRMWARE"

# Copy UEFI firmware to ESP
sudo cp -r "$UEFI_FIRMWARE"/* /mnt/boot/
log "UEFI firmware installed to /mnt/boot"

# --- Step 4: Install NixOS ---
log "Step 4: Installing NixOS to /mnt..."
set +e
sudo nixos-install --system "$SYSTEM_PATH" --root /mnt --no-root-passwd 2>&1 | tee /tmp/nixos-install.log
INSTALL_EXIT=$?
set -e

[ $INSTALL_EXIT -ne 0 ] && warn "nixos-install exited with code $INSTALL_EXIT (may be OK for cross-arch)"
[ ! -d "/mnt/nix/store" ] || [ -z "$(ls -A /mnt/nix/store 2>/dev/null)" ] && error "Installation failed: /mnt/nix/store is empty"
log "Nix store populated successfully."

# --- Step 5: Set ZFS bootfs property ---
log "Step 5: Setting ZFS bootfs property..."
sudo zpool set bootfs=zroot/root zroot

# --- Step 6: Write hostid for ZFS imports ---
log "Step 6: Writing hostid for ZFS..."
HOSTID=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.networking.hostId" 2>/dev/null || true)
if [[ -n "$HOSTID" && "$HOSTID" =~ ^[0-9a-fA-F]{8}$ ]]; then
    sudo mkdir -p /mnt/etc
    printf '%s' "$HOSTID" | xxd -r -p | sudo tee /mnt/etc/hostid >/dev/null
    log "Hostid written: $HOSTID"
fi

# --- Step 7: Manual boot population (cross-arch workaround) ---
log "Step 7: Populating boot partition (cross-arch workaround)..."

KERNEL=$(readlink -f "$SYSTEM_PATH/kernel")
INITRD=$(readlink -f "$SYSTEM_PATH/initrd")
INIT="$SYSTEM_PATH/init"

sudo mkdir -p /mnt/boot/EFI/{BOOT,nixos,systemd}
sudo mkdir -p /mnt/boot/loader/entries

# Install systemd-boot from target store
SYSTEMD_BOOT=$(find /mnt/nix/store -name 'systemd-bootaa64.efi' 2>/dev/null | head -1)
[ -z "$SYSTEMD_BOOT" ] && error "Cannot find systemd-boot EFI binary"
sudo cp "$SYSTEMD_BOOT" /mnt/boot/EFI/BOOT/BOOTAA64.EFI
sudo cp "$SYSTEMD_BOOT" /mnt/boot/EFI/systemd/systemd-bootaa64.efi
log "systemd-boot installed"

# Create loader config
sudo tee /mnt/boot/loader/loader.conf > /dev/null <<EOF
timeout 3
default nixos.conf
editor yes
EOF

# Copy kernel and initrd
KERNEL_HASH=$(basename "$(dirname "$KERNEL")" | cut -c1-8)
sudo cp "$KERNEL" "/mnt/boot/EFI/nixos/kernel-${KERNEL_HASH}.efi"
sudo cp "$INITRD" "/mnt/boot/EFI/nixos/initrd-${KERNEL_HASH}.efi"

# Create boot entry
sudo tee /mnt/boot/loader/entries/nixos.conf > /dev/null <<EOF
title NixOS
linux /EFI/nixos/kernel-${KERNEL_HASH}.efi
initrd /EFI/nixos/initrd-${KERNEL_HASH}.efi
options init=$INIT root=ZFS=zroot/root
EOF
log "Boot entry created"

# --- Step 8: Cleanup ---
log "Step 8: Cleanup..."
sudo umount -R /mnt || warn "Some mounts may need manual cleanup"
sudo zpool export zroot || warn "zpool export failed"

log "=============================================="
log "SUCCESS! Installation complete."
log ""
log "Next steps:"
log "  1. Unplug the Samsung T5 SSD"
log "  2. Connect to Raspberry Pi 4 (Blue USB 3.0 port)"
log "  3. Remove any SD card"
log "  4. Power on"
log "=============================================="
