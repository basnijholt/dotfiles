#!/usr/bin/env bash

# Usage: ./migrate-vm.sh <qcow2-file> <vm-name>

# NOTE: First run `sudo usermod -aG incus-admin $USER`
#       and re-login to have permissions.

QCOW2_FILE=$1
VM_NAME=$2

# Validate inputs
if [ -z "$QCOW2_FILE" ] || [ -z "$VM_NAME" ]; then
  echo "Usage: ./migrate-vm.sh <qcow2-file> <vm-name>"
  exit 1
fi

if [ ! -f "$QCOW2_FILE" ]; then
    echo "Error: File '$QCOW2_FILE' not found."
    exit 1
fi

echo "Preparing to migrate '$QCOW2_FILE' to VM '$VM_NAME'..."

# Create temporary metadata for Incus import
echo "Generating metadata..."
cat <<EOF > metadata.yaml
architecture: x86_64
creation_date: $(date +%s)
properties:
  description: Imported from $QCOW2_FILE
  os: linux
EOF

tar czf metadata.tar.gz metadata.yaml

# Import the image
echo "Importing disk image to Incus storage (this may take a while)..."
IMAGE_ALIAS="migration-temp-$(date +%s)"
incus image import metadata.tar.gz "$QCOW2_FILE" --alias "$IMAGE_ALIAS"

# Create the VM from the image
echo "Creating VM '$VM_NAME'..."
incus init "$IMAGE_ALIAS" "$VM_NAME" --vm

# Cleanup temporary image and files
echo "Cleaning up..."
incus image delete "$IMAGE_ALIAS"
rm metadata.yaml metadata.tar.gz

# Optional: Set defaults
incus config set "$VM_NAME" limits.memory 4GB
incus config set "$VM_NAME" limits.cpu 2

# Start the VM
incus start "$VM_NAME"

echo "✅ Success! VM '$VM_NAME' is running."
echo "   You can now safely delete the original '$QCOW2_FILE' if you verify the VM works."
echo "   Console: incus console $VM_NAME"
