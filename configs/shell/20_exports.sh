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
export MY_OPENAI_BASE_URL=http://llama.local/v1
export XDG_CONFIG_HOME="$HOME/.config"
export OLLAMA_KEEP_ALIVE="1h"
export LESS="-R"  # Enable colors in less (avoid --mouse, breaks text selection)
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1  # Disable Claude Code auto-updater and telemetry

# Make nix-ld libraries available to nix Python (e.g., pipx-installed agent-cli with sounddevice)
if [[ -d "/run/current-system/sw/share/nix-ld/lib" ]]; then
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
