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

# Build system (separately, because nixos-install --flake uses --store /mnt which breaks binfmt)
if [[ -n "${1:-}" ]]; then
    SYSTEM="$1"
    echo "Using pre-built system: $SYSTEM"
else
    [[ ! -f /proc/sys/fs/binfmt_misc/aarch64-linux ]] && { echo "Enable aarch64 emulation or provide pre-built path"; exit 1; }
    echo "Building NixOS system..."
    SYSTEM=$(nix build "$FLAKE_DIR#nixosConfigurations.$FLAKE_ATTR.config.system.build.toplevel" --no-link --print-out-paths)
    echo "Built: $SYSTEM"
fi

# Install to target
sudo nixos-install --system "$SYSTEM" --root /mnt --no-root-passwd

# Write hostid for ZFS
HOSTID=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.$FLAKE_ATTR.config.networking.hostId" 2>/dev/null || true)
[[ $HOSTID =~ ^[0-9a-fA-F]{8}$ ]] && printf '%s' "$HOSTID" | xxd -r -p | sudo tee /mnt/etc/hostid >/dev/null

# Pre-create WiFi profile (nixos-install --system doesn't run activation scripts)
if [[ -f "$SCRIPT_DIR/wifi.nix" ]]; then
    SSID=$(grep -oP 'ssid = "\K[^"]*' "$SCRIPT_DIR/wifi.nix" | head -1)
    PSK=$(grep -oP 'psk = "\K[^"]*' "$SCRIPT_DIR/wifi.nix" | head -1)
    if [[ -n "$SSID" && -n "$PSK" ]]; then
        echo "Creating WiFi profile for: $SSID"
        sudo mkdir -p /mnt/etc/NetworkManager/system-connections
        sudo tee /mnt/etc/NetworkManager/system-connections/Home-WiFi.nmconnection >/dev/null <<EOF
[connection]
id=Home-WiFi
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$PSK

[ipv4]
method=auto

[ipv6]
method=auto
EOF
        sudo chmod 600 /mnt/etc/NetworkManager/system-connections/Home-WiFi.nmconnection
    fi
fi

# Cleanup
sudo umount -R /mnt
sudo zpool export zroot

echo "Done! Connect SSD to Pi 4 (blue USB 3.0 port)."
