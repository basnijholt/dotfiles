#!/usr/bin/env bash
set -euo pipefail

# Pi 3 SSD Installer
# Run from bootstrap SD card after cloning dotfiles

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIFI_NIX="$SCRIPT_DIR/../pi4/wifi.nix"

# Preflight checks
[[ $EUID -eq 0 ]] && { echo "Error: Run as normal user, not root"; exit 1; }
[[ ! -f "$WIFI_NIX" ]] && { echo "Error: ../pi4/wifi.nix not found"; exit 1; }

echo "WARNING: This will destroy all data on the target disk."
read -p "Press Enter to continue (Ctrl+C to abort)..."

# Partition and mount SSD
sudo nix run github:nix-community/disko -- --mode disko "$SCRIPT_DIR/disko.nix"

# Build system (path:. includes gitignored wifi.nix)
echo "Building NixOS system..."
SYSTEM=$(nix build "path:$SCRIPT_DIR/../..#nixosConfigurations.pi3.config.system.build.toplevel" --impure --no-link --print-out-paths)

# Install
sudo nixos-install --system "$SYSTEM" --root /mnt --no-root-passwd

# Cleanup
sudo umount -R /mnt
sudo zpool export zroot

echo "Done! Copy boot files from SSD ESP to SD card, then reboot."
