#!/usr/bin/env bash

# -- Dotbins: ensures uv is in the PATH
source "$HOME/.dotbins/shell/bash.sh"

tools=(
  asciinema
  black
  bump-my-version
  clip-files
  conda-lock
  compose-farm
  dotbins
  dotbot
  fileup
  "llm --with llm-gemini --with llm-anthropic --with llm-ollama"
  markdown-code-runner
  mypy
  "pre-commit --with pre-commit-uv"
  prek
  pygount
  rsync-time-machine
  ruff
  smassh
  truenas-unlock
  tuitorial
  "unidep[all]"
)

for tool in "${tools[@]}"; do
  uv tool install $tool &
done
wait

uv tool upgrade --all
