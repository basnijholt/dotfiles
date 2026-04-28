#!/usr/bin/env bash
set -e

SOURCE_REMOTE="truenas"
SOURCE_IP="192.168.1.4"
CONTAINER="nix-cache"

echo "🚀 Starting migration of '$CONTAINER' from $SOURCE_REMOTE ($SOURCE_IP) to local HP..."

# 1. Check/Add Remote
if ! incus remote list | grep -q "$SOURCE_REMOTE"; then
    echo "⚠️  Remote '$SOURCE_REMOTE' not found."
    echo "   Please run this command manually to establish trust, then re-run this script:"
    echo "   incus remote add $SOURCE_REMOTE $SOURCE_IP"
    echo ""
    echo "   (Tip: Generate a token on TrueNAS with 'incus config trust add hp')"
    exit 1
fi

# 2. Initial Copy
echo "📦 Performing initial copy (hot)..."
incus copy "$SOURCE_REMOTE:$CONTAINER" local: --refresh 

# 3. Final Sync
echo "⏸️  Stopping source container..."
incus stop "$SOURCE_REMOTE:$CONTAINER"

echo "📦 Performing final sync (cold)..."
incus copy "$SOURCE_REMOTE:$CONTAINER" local: --refresh 

# 4. Start
echo "▶️  Starting local container..."
incus start "$CONTAINER"

echo "✅ Migration complete!"
echo "   Verify with: incus list"
echo "   Don't forget to delete the old one after verifying: incus delete $SOURCE_REMOTE:$CONTAINER"
