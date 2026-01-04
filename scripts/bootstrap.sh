#!/usr/bin/env bash
#
# Universal one-liner bootstrap for these dotfiles.
# Works on macOS and Linux (Alpine, Debian, Ubuntu, Fedora, Arch, etc.)
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/basnijholt/dotfiles/public/scripts/bootstrap.sh)"
#
# Options (env vars):
#   DOTFILES_DIR      Target directory (default: ~/dotfiles)
#   DOTFILES_BRANCH   Git branch to install (default: public)
#   DOTFILES_REPO     Repo URL (default: https://github.com/basnijholt/dotfiles.git)
#
set -euo pipefail

log() {
  echo "[dotfiles] $*"
}

OS="$(uname)"
ARCH="$(uname -m)"

# Map to dotbins naming
[[ "$OS" == "Darwin" ]] && DOTBINS_OS="macos" || DOTBINS_OS="linux"
case "$ARCH" in
  x86_64)        DOTBINS_ARCH="amd64" ;;
  aarch64|arm64) DOTBINS_ARCH="arm64" ;;
  *)             DOTBINS_ARCH="" ;;
esac

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-public}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/basnijholt/dotfiles.git}"

if [[ -e "$DOTFILES_DIR" ]]; then
  log "Target directory already exists: $DOTFILES_DIR"
  log "Move it aside or set DOTFILES_DIR to a different path."
  exit 1
fi

# --- Install dependencies ---
log "Installing dependencies for $OS..."

if [[ "$OS" == "Darwin" ]]; then
  # macOS: Xcode CLT + Homebrew
  if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode Command Line Tools..."
    xcode-select --install || true
    log "If prompted, finish installing CLT and re-run this script."
  fi

  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  BREW_PATH="/opt/homebrew/bin/brew"
  [[ -x "$BREW_PATH" ]] || BREW_PATH="/usr/local/bin/brew"
  eval "$("$BREW_PATH" shellenv)"

  log "Installing prerequisites via Homebrew..."
  brew update
  brew install git git-lfs zsh eza
  brew install --cask font-fira-mono-nerd-font || true

else
  # Linux: detect package manager
  if command -v apk >/dev/null 2>&1; then
    log "Found Alpine (apk)"
    apk add --no-cache git git-lfs bash zsh python3 curl || true
  elif command -v apt-get >/dev/null 2>&1; then
    log "Found Debian/Ubuntu (apt)"
    sudo apt-get update
    sudo apt-get install -y git git-lfs zsh python3 curl || true
  elif command -v dnf >/dev/null 2>&1; then
    log "Found Fedora/RHEL (dnf)"
    sudo dnf install -y git git-lfs zsh python3 curl || true
  elif command -v pacman >/dev/null 2>&1; then
    log "Found Arch (pacman)"
    sudo pacman -Sy --noconfirm git git-lfs zsh python curl || true
  else
    log "No supported package manager found. Ensure git, git-lfs, and zsh are installed."
  fi
fi

# --- Clone and setup ---
log "Initializing Git LFS..."
git lfs install || true

log "Cloning dotfiles ($DOTFILES_BRANCH) into $DOTFILES_DIR..."
GIT_LFS_SKIP_SMUDGE=1 git clone --depth=1 --branch "$DOTFILES_BRANCH" --single-branch \
  "$DOTFILES_REPO" "$DOTFILES_DIR"

log "Configuring Git to use HTTPS for submodules..."
git config --global url."https://github.com/".insteadOf git@github.com:

log "Initializing submodules..."
GIT_LFS_SKIP_SMUDGE=1 git -C "$DOTFILES_DIR" submodule update --init --recursive --depth=1 --jobs 8 || {
  log "Warning: Some submodules failed to clone (private repos?). Continuing anyway..."
}

# --- Fetch platform-specific binaries ---
if [[ -n "$DOTBINS_ARCH" ]]; then
  log "Fetching $DOTBINS_OS/$DOTBINS_ARCH dotbins binaries..."
  (
    cd "$DOTFILES_DIR/submodules/mydotbins"
    git lfs install --local
    git lfs pull --include="$DOTBINS_OS/$DOTBINS_ARCH/**"
    git lfs checkout --include="$DOTBINS_OS/$DOTBINS_ARCH/**"
  ) || log "Warning: LFS pull failed (no SSH keys?). Binaries not fetched."
else
  log "Skipping dotbins binary fetch (unsupported platform)."
fi

# Clean up global config
git config --global --unset url."https://github.com/".insteadOf || true

# --- Run dotbot installer ---
log "Running dotfiles installer..."
(
  cd "$DOTFILES_DIR"
  ./install || true
)

# --- macOS-specific post-install ---
if [[ "$OS" == "Darwin" ]]; then
  log "Configuring Terminal.app (dark theme + Nerd Font)..."
  defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
  defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
  osascript -e 'tell application "Terminal" to set font name of settings set "Pro" to "FiraMono Nerd Font Mono"' 2>/dev/null || true
  osascript -e 'tell application "Terminal" to set font size of settings set "Pro" to 12' 2>/dev/null || true

  log "Setting zsh as default shell..."
  BREW_ZSH="/opt/homebrew/bin/zsh"
  [[ ! -f "$BREW_ZSH" ]] && BREW_ZSH="/usr/local/bin/zsh"
  if [[ -f "$BREW_ZSH" ]] && ! grep -q "$BREW_ZSH" /etc/shells 2>/dev/null; then
    echo "$BREW_ZSH" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
  fi
  if [[ -f "$BREW_ZSH" ]] && [[ "$SHELL" != "$BREW_ZSH" ]]; then
    chsh -s "$BREW_ZSH" 2>/dev/null || log "Could not change shell; run: chsh -s $BREW_ZSH"
  fi
fi

log ""
log "Done! Restart your shell or run: source ~/.zshrc"
if [[ "$OS" == "Darwin" ]]; then
  log ""
  log "Terminal.app configured with:"
  log "  - Dark theme (Pro profile)"
  log "  - FiraMono Nerd Font Mono (size 12)"
  log "  - zsh as default shell"
fi
