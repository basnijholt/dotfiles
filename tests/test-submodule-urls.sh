#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

while read -r name url; do
  if [[ $url == git@github.com:* ]]; then
    printf 'SSH transport is not allowed for %s: %s\n' "$name" "$url" >&2
    exit 1
  fi
done < <(git -C "$repo_root" config -f .gitmodules --get-regexp '^submodule\..*\.url$')

printf 'submodule URL tests passed\n'
