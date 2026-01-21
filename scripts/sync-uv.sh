#!/usr/bin/env bash

# -- Dotbins: ensures uv is in the PATH
source "$HOME/.dotbins/shell/bash.sh"

xargs -P4 -I{} sh -c 'uv tool install {}' << 'EOF'
asciinema
black
bump-my-version
clip-files
conda-lock
compose-farm
dotbins
dotbot
fileup
llm --with llm-gemini --with llm-anthropic --with llm-ollama
markdown-code-runner
mypy
pre-commit --with pre-commit-uv
prek
pygount
rsync-time-machine
ruff
smassh
truenas-unlock
tuitorial
unidep[all]
EOF

uv tool upgrade --all
