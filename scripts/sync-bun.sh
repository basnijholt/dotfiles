#!/usr/bin/env bash

# -- Dotbins: ensures bun is in the PATH
source "$HOME/.dotbins/shell/bash.sh"

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

# T3's node-pty dependency has no Linux prebuild, so build its native addon.
bun install -g node-gyp@latest
(
    cd "$HOME/.bun/install/global/node_modules/t3/node_modules/node-pty"
    node-gyp rebuild
)
