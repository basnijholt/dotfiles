#!/usr/bin/env bash
set -euo pipefail

# Pi 3 SSD Installer - nixos-raspberrypi + ZFS
# Run from x86_64 machine with aarch64 emulation enabled

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLAKE_ATTR="pi3"

# Preflight
[[ $EUID -eq 0 ]] && { echo "Run as normal user"; exit 1; }
[[ ! -f /proc/sys/fs/binfmt_misc/aarch64-linux ]] && { echo "Enable aarch64 emulation"; exit 1; }
grep -q zfs /proc/modules || sudo modprobe zfs

echo "WARNING: This will destroy all data on the target disk. Ctrl+C to abort."
read -p "Press Enter to continue..."

# Partition + mount
sudo nix run github:nix-community/disko -- --mode disko "$SCRIPT_DIR/disko.nix"

# Install
sudo nixos-install --flake "$FLAKE_DIR#$FLAKE_ATTR" --root /mnt --no-root-passwd

# Write hostid for ZFS
HOSTID=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.$FLAKE_ATTR.config.networking.hostId" 2>/dev/null || true)
[[ $HOSTID =~ ^[0-9a-fA-F]{8}$ ]] && printf '%s' "$HOSTID" | xxd -r -p | sudo tee /mnt/etc/hostid >/dev/null

# Cleanup
sudo umount -R /mnt
sudo zpool export zroot

echo "Done! Connect SSD to Pi 3."
