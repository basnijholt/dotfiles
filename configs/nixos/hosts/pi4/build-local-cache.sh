#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CACHE_HOST="${CACHE_HOST:-basnijholt@nix-cache.local}"

echo "Building pi4 locally..."
SYSTEM="$(
  nix build "path:$FLAKE_DIR#nixosConfigurations.pi4.config.system.build.toplevel" \
    --impure \
    --no-link \
    --max-jobs "${MAX_JOBS:-1}" \
    --option cores "${CORES:-1}" \
    --print-out-paths
)"

echo "Copying closure to $CACHE_HOST..."
nix copy --to "ssh-ng://$CACHE_HOST" "$SYSTEM"

echo "Done: $SYSTEM"
