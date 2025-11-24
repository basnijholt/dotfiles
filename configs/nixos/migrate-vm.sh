#!/usr/bin/env bash

# Usage: ./migrate-vm.sh <qcow2-file> <vm-name>

QCOW2_FILE=$1
VM_NAME=$2

# Validate inputs
if [ -z "$QCOW2_FILE" ] || [ -z "$VM_NAME" ]; then
  echo "Usage: ./migrate-vm.sh <qcow2-file> <vm-name>"
  exit 1
fi

# Get absolute path to the qcow2 file (required for Incus)
ABS_PATH=$(readlink -f "$QCOW2_FILE")

echo "Creating VM '$VM_NAME' from disk '$ABS_PATH'..."

# Create an empty VM
incus init --vm --empty "$VM_NAME"

# Attach the QCow2 file as the root disk
# "boot.priority=10" ensures it tries to boot from this disk
incus config device add "$VM_NAME" root disk source="$ABS_PATH" boot.priority=10

# Optional: Set a reasonable default memory/CPU (can be changed later)
incus config set "$VM_NAME" limits.memory 4GB
incus config set "$VM_NAME" limits.cpu 2

# Start the VM
incus start "$VM_NAME"

echo "VM '$VM_NAME' started!"
echo "⚠️  IMPORTANT: Do not delete '$QCOW2_FILE'. It is now the live disk for this VM."
echo "   To access the console: incus console $VM_NAME"
