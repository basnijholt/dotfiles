# misc.sh - meant to be sourced in .bash_profile/.zshrc

# -- Homebrew (before dotbins because eza is not in dotbins on MacOS)
if [ -f "/opt/homebrew/bin/brew" ]; then
   eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Clear the config override inherited from the retired ZFS daemon setup.
if [ "${ATUIN_CONFIG_DIR:-}" = "$HOME/.config/atuin/zfs" ]; then
  unset ATUIN_CONFIG_DIR
fi

# Prefer NixOS's Atuin so the shell client and its daemon use the same package.
# Dotbins remains the provider on non-NixOS machines.
if [ -x /run/current-system/sw/bin/atuin ]; then
  atuin() {
    /run/current-system/sw/bin/atuin "$@"
  }
fi

# -- Dotbins
[ -n "$ZSH_VERSION" ] && source "$HOME/.dotbins/shell/zsh.sh"
[ -n "$BASH_VERSION" ] && source "$HOME/.dotbins/shell/bash.sh"

# -- Rust
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# -- Non-public parts
if [ -f "$HOME/dotfiles/secrets/configs/shell/main.sh" ]; then
    . "$HOME/dotfiles/secrets/configs/shell/main.sh"
fi

# -- LM Studio CLI (lms)
if [ -f "$HOME/.lmstudio/bin/lms" ]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
fi
