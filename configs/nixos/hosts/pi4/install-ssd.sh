#!/usr/bin/env bash
set -euo pipefail

# Pi 4 SSD Installer
# Run from bootstrap SD card after cloning dotfiles

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Preflight checks
[[ $EUID -eq 0 ]] && { echo "Error: Run as normal user, not root"; exit 1; }
[[ ! -f "$SCRIPT_DIR/wifi.nix" ]] && { echo "Error: wifi.nix not found"; exit 1; }

echo "WARNING: This will destroy all data on the target disk."
read -p "Press Enter to continue (Ctrl+C to abort)..."

# Partition and mount SSD
sudo nix run github:nix-community/disko -- --mode disko "$SCRIPT_DIR/disko.nix"

# Build system (path:. includes gitignored wifi.nix)
echo "Building NixOS system..."
SYSTEM=$(nix build "path:$SCRIPT_DIR/../..#nixosConfigurations.pi4.config.system.build.toplevel" --impure --no-link --print-out-paths)

# Install
sudo nixos-install --system "$SYSTEM" --root /mnt --no-root-passwd

# Cleanup
sudo umount -R /mnt
sudo zpool export zroot

echo "Done! Remove SD card and reboot to boot from SSD."
