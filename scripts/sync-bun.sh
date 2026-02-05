#!/usr/bin/env bash

# -- Dotbins: ensures bun is in the PATH
source "$HOME/.dotbins/shell/bash.sh"

packages=(
    @google/gemini-cli@latest
    @just-every/code@latest
    @openai/codex@latest
    @anthropic-ai/claude-code@latest
    opencode-ai@latest
)
bun install -g "${packages[@]}"
