#!/usr/bin/env bash
set -euo pipefail

# Deploy Pi3 config from PC (avoids OOM on Pi3's 1GB RAM)
# Usage: ./deploy.sh [user@host]

TARGET="${1:-nixos@pi3.local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$SCRIPT_DIR/../.."

echo "Building Pi3 system..."
SYSTEM=$(nix build "path:$FLAKE_DIR#nixosConfigurations.pi3.config.system.build.toplevel" --impure --no-link --print-out-paths)

echo "Copying to $TARGET..."
nix copy --to "ssh://$TARGET" "$SYSTEM"

echo ""
echo "Done! Now SSH in and run:"
echo "  ssh $TARGET"
echo "  sudo $SYSTEM/bin/switch-to-configuration switch"
