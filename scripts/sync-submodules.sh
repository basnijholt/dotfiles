#!/usr/bin/env bash

# Sync all submodules to their latest remote versions
# This pulls the latest commits from each submodule's remote

set -e

cd ~/dotfiles

echo "🔄 Syncing submodule URLs..."
git submodule sync --recursive

echo "📥 Updating submodules to latest remote..."
git submodule update --init --recursive --remote

echo "✅ Submodules synced to latest remote commits"
