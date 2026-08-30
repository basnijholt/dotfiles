#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$DOTFILES_ROOT/secrets}"
SECRETS_REPO_URL="${SECRETS_REPO_URL:-git@github.com:basnijholt/dotfiles-secrets.git}"
HOSTNAME="${SYNC_SECRETS_HOSTNAME:-$(hostname -s)}"
ZFS_UNLOCK_CONFIG_TARGET="${ZFS_UNLOCK_CONFIG_TARGET:-$HOME/.config/zfs-unlock/config.yaml}"

case "$HOSTNAME" in
  basnijholt-macbook-pro-2|basnijholt-macbook-pro|pc|pi4)
    ;;
  *)
    echo "Skipping secrets on $HOSTNAME"
    exit 0
    ;;
esac

if [[ ! -e "$SECRETS_DIR" ]]; then
  echo "Cloning secrets on $HOSTNAME"
  git clone --branch main --single-branch "$SECRETS_REPO_URL" "$SECRETS_DIR"
else
  if [[ ! -e "$SECRETS_DIR/.git" ]] \
      || ! git -C "$SECRETS_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Secrets path is not a Git checkout: $SECRETS_DIR" >&2
    exit 1
  fi

  echo "Updating secrets to latest main on $HOSTNAME"
  if git -C "$SECRETS_DIR" show-ref --verify --quiet refs/heads/main; then
    git -C "$SECRETS_DIR" switch main
  else
    git -C "$SECRETS_DIR" fetch origin main
    git -C "$SECRETS_DIR" switch --create main --track origin/main
  fi
  git -C "$SECRETS_DIR" pull --ff-only origin main
fi

if [[ "$HOSTNAME" == pi4 ]]; then
  required_zfs_unlock_files=(
    configs/zfs-unlock/config.yaml
    configs/zfs-unlock/frigate_key
    configs/zfs-unlock/photos_export_key
    configs/zfs-unlock/photos_key
    configs/zfs-unlock/stash_key
    configs/zfs-unlock/zfs-unlock-receiver
  )

  for required_file in "${required_zfs_unlock_files[@]}"; do
    if [[ ! -f "$SECRETS_DIR/$required_file" ]]; then
      printf 'Missing required ZFS-unlock secret file: %s\n' "$required_file" >&2
      exit 1
    fi
  done

  if [[ ! -e "$ZFS_UNLOCK_CONFIG_TARGET" ]]; then
    mkdir -p "$(dirname "$ZFS_UNLOCK_CONFIG_TARGET")"
    rm -f "$ZFS_UNLOCK_CONFIG_TARGET"
    ln -s "$SECRETS_DIR/configs/zfs-unlock/config.yaml" "$ZFS_UNLOCK_CONFIG_TARGET"
  fi

  exit 0
fi

if [[ -f "$SECRETS_DIR/install" ]]; then
  echo "Installing secrets"
  "$SECRETS_DIR/install"
fi
