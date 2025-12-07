#!/usr/bin/env bash
set -e

# =======================================================================================
# Pi 4 Direct SSD Installer (ZFS Root + nixos-raspberrypi)
# =======================================================================================
# Installs NixOS directly onto a Samsung T5 SSD using the nixos-raspberrypi flake
# for proper kernel/firmware/bootloader support.
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

# --- Step 2: Build the system ---
log "Step 2: Building NixOS system (aarch64)..."
nix build "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel" --no-link
SYSTEM_PATH=$(nix path-info "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel")
log "Built: $SYSTEM_PATH"

# --- Step 3: Install to /mnt ---
log "Step 3: Installing NixOS to /mnt..."

# nixos-install copies the closure and runs activation
# The activation may fail in cross-arch chroot, but files get copied
set +e
sudo nixos-install --system "$SYSTEM_PATH" --root /mnt --no-root-passwd 2>&1 | tee /tmp/nixos-install.log
INSTALL_EXIT=$?
set -e

if [ $INSTALL_EXIT -ne 0 ]; then
    warn "nixos-install exited with code $INSTALL_EXIT (common for cross-arch)"
    warn "Checking if files were copied..."
fi

if [ ! -d "/mnt/nix/store" ] || [ -z "$(ls -A /mnt/nix/store 2>/dev/null)" ]; then
    error "Installation failed: /mnt/nix/store is empty"
fi
log "Nix store populated successfully."

# --- Step 4: Populate bootloader ---
log "Step 4: Populating bootloader (firmware + extlinux)..."

# Get the populate commands from the built system
FIRMWARE_CMD=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.boot.loader.raspberryPi.firmwarePopulateCmd")
BOOT_CMD=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.boot.loader.raspberryPi.bootPopulateCmd")

log "Running firmware populate..."
sudo $FIRMWARE_CMD -c "$SYSTEM_PATH" -f /mnt/boot/firmware

log "Running boot populate..."
sudo $BOOT_CMD -c "$SYSTEM_PATH" -b /mnt/boot

# Verify (use sudo - firmware partition has restrictive permissions)
log "Verifying bootloader files..."
if ! sudo test -f /mnt/boot/firmware/config.txt; then
    error "config.txt missing from /mnt/boot/firmware"
fi
if ! sudo test -d /mnt/boot/extlinux; then
    error "extlinux directory missing from /mnt/boot"
fi
log "Bootloader verified."

# --- Step 5: Cleanup ---
log "Step 5: Cleanup..."
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
log "The Pi should boot and connect to WiFi automatically."
log "=============================================="
