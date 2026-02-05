#!/usr/bin/env bash

# Updates the local system using the nixpkgs revision cached by the build server.
# This ensures a high binary cache hit rate.

set -e

CACHE_HOST="${CACHE_HOST:-basnijholt@nix-cache.local}"
# Use the short hostname (e.g., 'pc' instead of 'pc.local')
HOSTNAME="${HOSTNAME:-$(hostname -s)}"
REMOTE_FILE="/var/lib/nix-auto-build/${HOSTNAME}.rev"

echo "🔍 Fetching target revision for '$HOSTNAME' from '$CACHE_HOST'..."

# Fetch the revision via SSH.
# Requires SSH access to the cache host.
if ! TARGET_REV=$(ssh "$CACHE_HOST" "cat $REMOTE_FILE" 2>/dev/null); then
    echo "❌ Error: Could not retrieve revision from $CACHE_HOST:$REMOTE_FILE"
    echo "   - Is the host '$CACHE_HOST' reachable?"
    echo "   - Has the auto-build service successfully built '$HOSTNAME' yet?"
    exit 1
fi

# Trim whitespace
TARGET_REV=$(echo "$TARGET_REV" | xargs)

if [ -z "$TARGET_REV" ]; then
    echo "❌ Error: Retrieved empty revision from server."
    exit 1
fi

echo "🎯 Target Nixpkgs Revision: $TARGET_REV"

echo "🚀 Starting rebuild..."
echo "   Command: nixos-rebuild switch --flake .#${HOSTNAME} --override-input nixpkgs github:NixOS/nixpkgs/${TARGET_REV}"

# Run the rebuild
# We use "$@" to pass any extra arguments (like --show-trace or --fast)
nixos-rebuild switch \
    --flake ".#${HOSTNAME}" \
    --override-input nixpkgs "github:NixOS/nixpkgs/${TARGET_REV}" \
    --use-remote-sudo \
    "$@"

echo "✅ Update complete!"

