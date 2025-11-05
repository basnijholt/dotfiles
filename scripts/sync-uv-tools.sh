#! /usr/bin/env bash

# -- Dotbins: ensures uv is in the PATH
source "$HOME/.dotbins/shell/bash.sh"

uv tool install asciinema
uv tool install black
uv tool install bump-my-version
uv tool install clip-files
uv tool install conda-lock
uv tool install dotbins
uv tool install dotbot
uv tool install fileup
uv tool install llm --with llm-gemini --with llm-anthropic --with llm-ollama
uv tool install markdown-code-runner
uv tool install mypy
uv tool install pre-commit --with pre-commit-uv
uv tool install pygount
uv tool install rsync-time-machine
uv tool install ruff
uv tool install smassh
uv tool install tuitorial
uv tool install "unidep[all]"
uv tool upgrade --all
