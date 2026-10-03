#!/usr/bin/env bash
set -euo pipefail

# -- Dotbins: ensures bun is in the PATH
source "${DOTBINS_SHELL:-$HOME/.dotbins/shell/bash.sh}"

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PATH="$BUN_INSTALL/bin:$PATH"

packages=(
    @google/gemini-cli@latest
    @just-every/code@latest
    @openai/codex@latest
    @mariozechner/pi-coding-agent@latest
    opencode-ai@latest
    @anthropic-ai/claude-code@latest
    t3@latest
)
bun install -g "${packages[@]}"
