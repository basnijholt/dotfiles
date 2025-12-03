#!/usr/bin/env bash
set -euo pipefail

# Create a dev-vm Incus VM with NixOS
#
# Usage: ./create-dev-vm.sh [vm-name] [memory] [cpus] [disk-size]
#
# Examples:
#   ./create-dev-vm.sh                    # dev-vm with defaults
#   ./create-dev-vm.sh dev-vm-2           # custom name
#   ./create-dev-vm.sh dev-vm 16GiB 8     # 16GB RAM, 8 CPUs

VM_NAME="${1:-dev-vm}"
MEMORY="${2:-8GiB}"
CPUS="${3:-4}"
DISK_SIZE="${4:-50GiB}"
FLAKE_REF="${FLAKE_REF:-github:basnijholt/dotfiles?dir=configs/nixos}"
ISO_PATH="${ISO_PATH:-/tmp/nixos.iso}"

# Nix binary cache configuration
NIX_SUBSTITUTERS="http://nix-cache.local:5000 https://cache.nixos.org https://nix-community.cachix.org https://cache.nixos-cuda.org"
NIX_TRUSTED_KEYS="build-vm-1:CQeZikX76TXVMm+EXHMIj26lmmLqfSxv8wxOkwqBb3g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="

# Find the nixos config directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="$SCRIPT_DIR/../configs/nixos"

echo "=== Creating NixOS dev-vm: $VM_NAME ==="
echo "    Memory: $MEMORY, CPUs: $CPUS, Disk: $DISK_SIZE"
echo ""

# Check if ISO exists, offer to build it
if [[ ! -f "$ISO_PATH" ]]; then
    echo "NixOS ISO not found at $ISO_PATH"
    echo ""
    read -p "Build it now? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Building NixOS installer ISO..."
        nix build "$NIXOS_DIR#nixosConfigurations.installer.config.system.build.isoImage" \
            --option substituters "$NIX_SUBSTITUTERS" \
            --option trusted-public-keys "$NIX_TRUSTED_KEYS" \
            --out-link /tmp/nixos-iso-result
        cp /tmp/nixos-iso-result/iso/*.iso "$ISO_PATH"
        rm /tmp/nixos-iso-result
        echo "ISO built: $ISO_PATH"
    else
        echo "Aborted. Build the ISO manually with:"
        echo "  cd configs/nixos"
        echo "  nix build .#nixosConfigurations.installer.config.system.build.isoImage"
        echo "  cp result/iso/*.iso $ISO_PATH"
        exit 1
    fi
fi

# Check if VM already exists
if incus info "$VM_NAME" &>/dev/null; then
    echo "Error: VM '$VM_NAME' already exists"
    echo "Delete it with: incus delete $VM_NAME --force"
    exit 1
fi

# Create empty VM
echo "Creating VM..."
incus create "$VM_NAME" --vm --empty \
    -c limits.memory="$MEMORY" \
    -c limits.cpu="$CPUS" \
    -c security.secureboot=false \
    -d root,size="$DISK_SIZE"

# Attach ISO
echo "Attaching NixOS ISO..."
incus config device add "$VM_NAME" iso disk source="$ISO_PATH" boot.priority=10

# Start VM
echo "Starting VM (booting from ISO)..."
incus start "$VM_NAME"

# Wait for VM to get an IP
echo "Waiting for VM to boot and get IP..."
for i in {1..60}; do
    IP=$(incus list "$VM_NAME" -f csv -c 4 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)
    if [[ -n "$IP" ]]; then
        break
    fi
    sleep 2
done

if [[ -z "$IP" ]]; then
    echo "Error: VM did not get an IP address"
    echo "Check with: incus list"
    exit 1
fi

echo ""
echo "=== VM is running at $IP ==="
echo ""
echo "SSH in and run these commands to install NixOS:"
echo ""
echo "  ssh root@$IP"
echo ""
echo "  # Partition and format"
echo "  nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \\"
echo "    --mode destroy,format,mount \\"
echo "    --yes-wipe-all-disks \\"
echo "    --flake '$FLAKE_REF#dev-vm'"
echo ""
echo "  # Install NixOS"
echo "  nixos-install --root /mnt --no-root-passwd \\"
echo "    --option substituters \"$NIX_SUBSTITUTERS\" \\"
echo "    --option trusted-public-keys \"$NIX_TRUSTED_KEYS\" \\"
echo "    --flake '$FLAKE_REF#dev-vm'"
echo ""
echo "  # Set user password"
echo "  nixos-enter --root /mnt -c 'passwd basnijholt'"
echo ""
echo "After installation, run from your host:"
echo ""
echo "  incus stop $VM_NAME --force"
echo "  incus config device remove $VM_NAME iso"
echo "  incus start $VM_NAME"
