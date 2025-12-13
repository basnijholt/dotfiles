#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

REPO_FW_DIR="$(dirname "$0")/firmware/brcm"
mkdir -p "$REPO_FW_DIR"

echo "🛠️  Preparing /lib/firmware for extraction (Overlay Hack)..."
mkdir -p /tmp/fw-upper /tmp/fw-work
if ! mount | grep -q "overlay on /lib/firmware"; then
    mount -t overlay overlay -o lowerdir=/lib/firmware,upperdir=/tmp/fw-upper,workdir=/tmp/fw-work /lib/firmware
fi
mkdir -p /lib/firmware/brcm

echo "🍎 Running extraction tool (choose Option 2)..."
get-apple-firmware

echo "💾 Copying firmware to repo: $REPO_FW_DIR"
cp /lib/firmware/brcm/* "$REPO_FW_DIR/"

echo "✅ Firmware saved!"
echo "👉 Now commit the new files in 'firmware/' and run 'nixos-rebuild switch'."
echo "   After that, WiFi will work automatically on boot without this script."
