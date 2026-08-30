#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

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

submodule_remote="$test_root/submodule-remote.git"
submodule_seed="$test_root/submodule-seed"
superproject="$test_root/superproject"
checkout="$test_root/checkout"

git init --bare --initial-branch=main "$submodule_remote" >/dev/null
git init --initial-branch=main "$submodule_seed" >/dev/null
(
  cd "$submodule_seed"
  git config user.email test@example.invalid
  git config user.name 'submodule URL test'
  printf 'fixture\n' >fixture
  git add fixture
  git commit -m 'fixture submodule' >/dev/null
  git remote add origin "$submodule_remote"
  git push origin main >/dev/null
)

git init --initial-branch=main "$superproject" >/dev/null
(
  cd "$superproject"
  git config user.email test@example.invalid
  git config user.name 'submodule URL test'
  git -c protocol.file.allow=always submodule add "$submodule_remote" modules/example >/dev/null
  git commit -m 'fixture superproject' >/dev/null
)
git clone --no-recurse "$superproject" "$checkout" >/dev/null
git -C "$checkout" submodule init >/dev/null
git -C "$checkout" config submodule.modules/example.url "$test_root/stale-does-not-exist.git"

submodule_command=$(awk '
  /^[[:space:]]*- command: git submodule/ {
    sub(/^[[:space:]]*- command: /, "")
    print
    exit
  }
' "$repo_root/install.conf.yaml")
if [[ -z "$submodule_command" ]]; then
  printf 'installer submodule action not found\n' >&2
  exit 1
fi
if ! (
  cd "$checkout"
  GIT_ALLOW_PROTOCOL=file bash -c "$submodule_command"
) >/dev/null 2>&1; then
  printf 'installer did not migrate a stale cached submodule URL\n' >&2
  exit 1
fi

printf 'submodule URL tests passed\n'
