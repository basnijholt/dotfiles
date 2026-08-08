#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SECRETS_DIR="$DOTFILES_ROOT/secrets"
SECRETS_REPO_URL="${SECRETS_REPO_URL:-git@github.com:basnijholt/dotfiles-secrets.git}"
HOSTNAME="$(hostname -s)"

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

if [[ -f "$SECRETS_DIR/install" ]]; then
  echo "Installing secrets"
  "$SECRETS_DIR/install"
fi
