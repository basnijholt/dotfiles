#!/usr/bin/env bash
# Setup rclone with Backblaze B2 + client-side encryption
set -euo pipefail

mkdir -p ~/.config/rclone

read -rp "B2 Key ID: " KEY_ID
read -rsp "B2 Key: " KEY; echo
read -rp "Bucket: " BUCKET
read -rsp "Encryption password: " PASS1; echo
read -rsp "Salt password: " PASS2; echo

cat > ~/.config/rclone/rclone.conf << EOF
[b2-raw]
type = b2
account = $KEY_ID
key = $KEY

[b2-encrypted]
type = crypt
remote = b2-raw:$BUCKET
password = $(rclone obscure "$PASS1")
password2 = $(rclone obscure "$PASS2")
filename_encryption = standard
directory_name_encryption = true
EOF

chmod 600 ~/.config/rclone/rclone.conf
echo "Config written to ~/.config/rclone/rclone.conf"
