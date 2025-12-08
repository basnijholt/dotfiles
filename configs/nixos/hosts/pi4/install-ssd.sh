#!/usr/bin/env bash
set -euo pipefail

# Pi 4 SSD Installer - nixos-raspberrypi + ZFS
# If pre-built on Mac, pass store path as argument to skip rebuild

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLAKE_ATTR="pi4"

# Preflight
[[ $EUID -eq 0 ]] && { echo "Run as normal user"; exit 1; }
grep -q zfs /proc/modules || sudo modprobe zfs

echo "WARNING: This will destroy all data on the target disk. Ctrl+C to abort."
read -p "Press Enter to continue..."

# Partition + mount
sudo nix run github:nix-community/disko -- --mode disko "$SCRIPT_DIR/disko.nix"

# Install - use pre-built path if provided, otherwise build locally
if [[ -n "${1:-}" ]]; then
    echo "Using pre-built system: $1"
    sudo nixos-install --system "$1" --root /mnt --no-root-passwd
else
    [[ ! -f /proc/sys/fs/binfmt_misc/aarch64-linux ]] && { echo "Enable aarch64 emulation or provide pre-built path"; exit 1; }
    sudo nixos-install --flake "$FLAKE_DIR#$FLAKE_ATTR" --root /mnt --no-root-passwd
fi

# Write hostid for ZFS
HOSTID=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.$FLAKE_ATTR.config.networking.hostId" 2>/dev/null || true)
[[ $HOSTID =~ ^[0-9a-fA-F]{8}$ ]] && printf '%s' "$HOSTID" | xxd -r -p | sudo tee /mnt/etc/hostid >/dev/null

# Cleanup
sudo umount -R /mnt
sudo zpool export zroot

echo "Done! Connect SSD to Pi 4 (blue USB 3.0 port)."
