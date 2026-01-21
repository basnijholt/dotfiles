#!/usr/bin/env bash
packages=(
    @google/gemini-cli@latest
    @just-every/code@latest
    @openai/codex@latest
    @anthropic-ai/claude-code@latest
    opencode-ai@latest
)
bun install -g "${packages[@]}"