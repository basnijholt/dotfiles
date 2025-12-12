#!/usr/bin/env bash
set -e

echo "⚠️  WARNING: This will WIPE /dev/nvme0n1 and install NixOS."
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo "🚀 Partitioning disk..."
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/macbook-air-intel/disko.nix

echo "🚀 Installing NixOS..."
nixos-install --flake .#macbook-air-intel

echo "✅ Done! Rebooting in 5 seconds..."
sleep 5
reboot
