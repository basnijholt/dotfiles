#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if ! urls=$(git -C "$repo_root" config -f .gitmodules --get-regexp '^submodule\..*\.url$'); then
  printf 'unable to parse .gitmodules\n' >&2
  exit 1
fi

while read -r name url; do
  if [[ $url == git@github.com:* ]]; then
    printf 'SSH transport is not allowed for %s: %s\n' "$name" "$url" >&2
    exit 1
  fi
done <<<"$urls"

printf 'submodule URL tests passed\n'
