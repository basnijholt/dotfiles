# exports.sh - meant to be sourced in .bash_profile/.zshrc

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR="nano"
export TMPDIR=/tmp # https://github.com/dotnet/runtime/issues/3168#issuecomment-389070397
export UPLOAD_FILE_TO="transfer.sh"  # For upload-file.sh
export PATH="$HOME/.local/bin:$PATH"  # Common place, e.g., my upload-file script
export PATH="$HOME/.local/npm/bin:$PATH"
export PATH="$PATH:$HOME/.lmstudio/bin"  # lmstudio
export PATH="/nix/var/nix/profiles/default/bin:$PATH"  # nix path
export PNPM_HOME="$HOME/.local/pnpm"
export PATH="$PNPM_HOME:$PATH"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export MY_OLLAMA_HOST=http://pc.local:11434
export XDG_CONFIG_HOME="$HOME/.config"
export OLLAMA_KEEP_ALIVE="1h"
export LESS="-R"  # Enable colors in less (avoid --mouse, breaks text selection)
