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

# T3's node-pty dependency has no Linux prebuild, so build its native addon.
bun install -g node-gyp@latest
node_pty_package=''
t3_global_dir="$BUN_INSTALL/install/global/node_modules/t3"
if ! node_pty_package=$(cd "$t3_global_dir" && node -p 'require.resolve("node-pty/package.json")'); then
    printf 'Could not resolve node-pty from T3 global modules.\n' >&2
    exit 1
fi
node_pty_dir=$(dirname "$node_pty_package")
if [[ ! -d "$node_pty_dir" ]]; then
    printf 'Resolved node-pty directory does not exist: %s\n' "$node_pty_dir" >&2
    exit 1
fi
(
    cd "$node_pty_dir"
    "$BUN_INSTALL/bin/node-gyp" rebuild
)
