#!/usr/bin/env bash
set -e

# =======================================================================================
# Pi 3 SSD Installer (nixos-raspberrypi + ZFS)
# =======================================================================================
# Uses nixos-raspberrypi flake for U-Boot boot with WiFi support.
# Debug host with HDMI/ethernet for troubleshooting.
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
log "Pi 3 installer (nixos-raspberrypi + ZFS)"

[ "$EUID" -eq 0 ] && error "Run as normal user (not root)."
[ ! -e "$DISK_ID" ] && error "Disk not found: $DISK_ID"
[ ! -f /proc/sys/fs/binfmt_misc/aarch64-linux ] && error "aarch64 emulation not enabled"
grep -q zfs /proc/modules || sudo modprobe zfs || error "ZFS not available"

echo -e "${RED}WARNING: ALL DATA ON THIS DISK WILL BE DESTROYED.${NC}"
read -p "Proceed? (y/N) " -n 1 -r; echo
[[ ! $REPLY =~ ^[Yy]$ ]] && error "Aborted."

# --- Step 1: Partition with Disko ---
log "Step 1: Partitioning..."
sudo nix run github:nix-community/disko -- --mode disko "$SCRIPT_DIR/disko.nix"

# --- Step 2: Build system ---
log "Step 2: Building NixOS..."
nix build "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel" --no-link
SYSTEM_PATH=$(nix path-info "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.system.build.toplevel")
log "Built: $SYSTEM_PATH"

# --- Step 3: Install NixOS ---
log "Step 3: Installing NixOS..."
set +e
sudo nixos-install --system "$SYSTEM_PATH" --root /mnt --no-root-passwd 2>&1 | tee /tmp/nixos-install.log
set -e

[ ! -d "/mnt/nix/store" ] && error "Installation failed"

# --- Step 4: ZFS setup ---
log "Step 4: ZFS setup..."
sudo zpool set bootfs=zroot/root zroot
HOSTID=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.${FLAKE_ATTR}.config.networking.hostId" 2>/dev/null || true)
if [[ -n "$HOSTID" && "$HOSTID" =~ ^[0-9a-fA-F]{8}$ ]]; then
    sudo mkdir -p /mnt/etc
    printf '%s' "$HOSTID" | xxd -r -p | sudo tee /mnt/etc/hostid >/dev/null
    log "Hostid written: $HOSTID"
fi

# --- Step 5: Cleanup ---
log "Step 5: Cleanup..."
sudo umount -R /mnt || true
sudo zpool export zroot || true

log "=============================================="
log "SUCCESS! Connect SSD to Pi 3."
log "nixos-raspberrypi handles boot firmware automatically."
log "=============================================="
