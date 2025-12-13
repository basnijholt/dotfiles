#!/usr/bin/env bash
#
# macOS one-liner installer for these dotfiles.
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/basnijholt/dotfiles/public/scripts/install-macos.sh)"
#
# Options (env vars):
#   DOTFILES_DIR      Target directory (default: ~/dotfiles)
#   DOTFILES_BRANCH  Git branch to install (default: public)
#   DOTFILES_REPO    Repo URL (default: https://github.com/basnijholt/dotfiles.git)
#
set -euo pipefail

log() {
  echo "[dotfiles-macos] $*"
}

if [[ "$(uname)" != "Darwin" ]]; then
  log "This installer is for macOS only."
  exit 1
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" && "$ARCH" != "aarch64" ]]; then
  log "Warning: mydotbins currently ships Apple Silicon (arm64) binaries only."
  log "Continuing, but some tools may be unavailable on Intel Macs."
fi

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-public}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/basnijholt/dotfiles.git}"

if [[ -e "$DOTFILES_DIR" ]]; then
  log "Target directory already exists: $DOTFILES_DIR"
  log "Move it aside or set DOTFILES_DIR to a different path."
  exit 1
fi

log "Checking for Xcode Command Line Tools..."
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools (a dialog may appear)..."
  xcode-select --install || true
  log "If prompted, finish installing CLT and re-run this script."
fi

if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  log "Homebrew installed, but brew not found in expected locations."
  exit 1
fi

log "Updating Homebrew and installing prerequisites..."
brew update
brew install git git-lfs zsh eza
brew install --cask font-fira-mono-nerd-font || true

log "Initializing Git LFS..."
git lfs install

log "Cloning dotfiles ($DOTFILES_BRANCH) into $DOTFILES_DIR..."
GIT_LFS_SKIP_SMUDGE=1 git clone --depth=1 --branch "$DOTFILES_BRANCH" --single-branch \
  "$DOTFILES_REPO" "$DOTFILES_DIR"

log "Configuring Git to use HTTPS for submodules..."
git -C "$DOTFILES_DIR" config url."https://github.com/".insteadOf git@github.com:

log "Initializing submodules (LFS skipped for now)..."
GIT_LFS_SKIP_SMUDGE=1 git -C "$DOTFILES_DIR" submodule update --init --recursive --jobs 8

log "Fetching Apple Silicon dotbins binaries..."
(
  cd "$DOTFILES_DIR/submodules/mydotbins"
  git lfs install --local
  git lfs pull --include="macos/arm64/**"
  git lfs checkout --include="macos/arm64/**"
)

log "Running dotfiles installer..."
(
  cd "$DOTFILES_DIR"
  ./install
)

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

log "Done! Restart your terminal for all changes to take effect."
log ""
log "Terminal.app is now configured with:"
log "  • Dark theme (Pro profile)"
log "  • FiraMono Nerd Font Mono (size 12)"
log "  • zsh as default shell"

