#!/usr/bin/env bash

# Usage: ./migrate-lxc.sh <backup-file.tar.zst> <container-name>

BACKUP_FILE=$1
CONTAINER_NAME=$2

# Create container (using Debian 12 as a generic base)
incus init images:debian/12 "$CONTAINER_NAME"

# Enable nesting (required for Docker, harmless for others)
incus config set "$CONTAINER_NAME" security.nesting true

# Start the container so we can exec into it
incus start "$CONTAINER_NAME"

# Stream the backup directly into the container
# This overwrites the template OS with the backup content
echo "Restoring $BACKUP_FILE to $CONTAINER_NAME..."
zstdcat "$BACKUP_FILE" | incus exec "$CONTAINER_NAME" -- tar -x -C /

# Restart to ensure all services boot cleanly from the restored rootfs
incus restart "$CONTAINER_NAME"

echo "Done! Container $CONTAINER_NAME is running."
