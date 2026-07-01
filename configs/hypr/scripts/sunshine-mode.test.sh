#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
script="$script_dir/sunshine-mode.sh"

bash -n "$script"

if rg -Fq '"${real_output},disable"' "$script"; then
  printf 'sunshine-mode must never disable the real desktop output\n' >&2
  exit 1
fi

printf 'sunshine-mode tests passed\n'
