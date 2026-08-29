#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/sync-local-dotfiles.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

git() {
  case "${SYNC_LOCAL_TEST_FAILURE:-}" in
    pull)
      [[ ${1:-} == pull ]] && return 1
      ;;
    submodule-sync)
      [[ ${1:-} == submodule && ${2:-} == sync ]] && return 1
      ;;
    submodule-update)
      [[ ${1:-} == submodule && ${2:-} == update ]] && return 1
      ;;
  esac

  return 0
}
export -f git

mkdir -p "$test_root/dotfiles/submodules/mydotbins"

for failure in pull submodule-sync submodule-update; do
  if (
    cd "$test_root"
    SYNC_LOCAL_TEST_FAILURE="$failure" bash "$script" sync
  ); then
    printf 'sync-local-dotfiles accepted a failed %s command\n' "$failure" >&2
    exit 1
  fi
done

(
  cd "$test_root"
  bash "$script" sync
)

printf 'sync-local-dotfiles tests passed\n'
