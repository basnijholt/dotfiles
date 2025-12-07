#!/usr/bin/env bash
set -e

# =======================================================================================
# Pi 3 UEFI SSD Installer (Declarative) - DEBUG HOST
# =======================================================================================
# Same as pi4 but with RPi3 firmware. Use with HDMI/ethernet to debug boot issues.
# =======================================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

FLAKE_ATTR="pi3"
DISK_ID="/dev/disk/by-id/usb-Samsung_Portable_SSD_T5_1234567A666E-0:0"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Pre-flight Checks ---
log "Pi 3 DEBUG installer - use with HDMI/ethernet"

[ "$EUID" -eq 0 ] && error "Run as normal user (not root)."
[ ! -e "$DISK_ID" ] && error "Disk not found: $DISK_ID"
[ ! -f /proc/sys/fs/binfmt_misc/aarch64-linux ] && error "aarch64 emulation not enabled"
grep -q zfs /proc/modules || sudo modprobe zfs || error "ZFS not available"

echo -e "${RED}WARNING: ALL DATA ON THIS DISK WILL BE DESTROYED.${NC}"
read -p "Proceed? (y/N) " -n 1 -r; echo
[[ ! $REPLY =~ ^[Yy]$ ]] && error "Aborted."

# --- Step 1: Partition ---
log "Step 1: Partitioning..."
sudo nix run github:nix-community/disko -- --mode disko "$SCRIPT_DIR/disko.nix"

# --- Step 2: Build system ---
log "Step 2: Building NixOS..."
nix build "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel" --no-link
SYSTEM_PATH=$(nix path-info "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel")

# --- Step 3: UEFI firmware from Nix config ---
log "Step 3: Getting RPi3 UEFI firmware from Nix..."
UEFI_FIRMWARE=$(nix build --no-link --print-out-paths "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.hardware.raspberry-pi.uefi.firmware")
[ -z "$UEFI_FIRMWARE" ] || [ ! -d "$UEFI_FIRMWARE" ] && error "Cannot get UEFI firmware from Nix"
sudo cp -r "$UEFI_FIRMWARE"/* /mnt/boot/

# --- Step 4: Install NixOS ---
log "Step 4: Installing NixOS..."
set +e
sudo nixos-install --system "$SYSTEM_PATH" --root /mnt --no-root-passwd 2>&1 | tee /tmp/nixos-install.log
set -e

[ ! -d "/mnt/nix/store" ] && error "Installation failed"

# --- Step 5-6: ZFS setup ---
log "Step 5: ZFS setup..."
sudo zpool set bootfs=zroot/root zroot
HOSTID=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.networking.hostId" 2>/dev/null || true)
if [[ -n "$HOSTID" && "$HOSTID" =~ ^[0-9a-fA-F]{8}$ ]]; then
    sudo mkdir -p /mnt/etc
    printf '%s' "$HOSTID" | xxd -r -p | sudo tee /mnt/etc/hostid >/dev/null
fi

# --- Step 6: Boot population ---
log "Step 6: Boot partition..."
KERNEL=$(readlink -f "$SYSTEM_PATH/kernel")
INITRD=$(readlink -f "$SYSTEM_PATH/initrd")

sudo mkdir -p /mnt/boot/EFI/{BOOT,nixos,systemd} /mnt/boot/loader/entries

SYSTEMD_BOOT=$(find /mnt/nix/store -name 'systemd-bootaa64.efi' 2>/dev/null | head -1)
[ -n "$SYSTEMD_BOOT" ] && sudo cp "$SYSTEMD_BOOT" /mnt/boot/EFI/BOOT/BOOTAA64.EFI
[ -n "$SYSTEMD_BOOT" ] && sudo cp "$SYSTEMD_BOOT" /mnt/boot/EFI/systemd/systemd-bootaa64.efi

sudo tee /mnt/boot/loader/loader.conf > /dev/null <<EOF
timeout 3
default nixos.conf
editor yes
EOF

KERNEL_HASH=$(basename "$(dirname "$KERNEL")" | cut -c1-8)
sudo cp "$KERNEL" "/mnt/boot/EFI/nixos/kernel-${KERNEL_HASH}.efi"
sudo cp "$INITRD" "/mnt/boot/EFI/nixos/initrd-${KERNEL_HASH}.efi"

sudo tee /mnt/boot/loader/entries/nixos.conf > /dev/null <<EOF
title NixOS
linux /EFI/nixos/kernel-${KERNEL_HASH}.efi
initrd /EFI/nixos/initrd-${KERNEL_HASH}.efi
options init=$SYSTEM_PATH/init root=ZFS=zroot/root
EOF

# --- Cleanup ---
log "Step 7: Cleanup..."
sudo umount -R /mnt || true
sudo zpool export zroot || true

log "=============================================="
log "SUCCESS! Connect SSD to Pi 3 with HDMI/ethernet."
log "Watch screen to see where boot fails."
log "=============================================="
