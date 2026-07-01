#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
script="$script_dir/sunshine-mode.sh"

bash -n "$script"

if rg -q 'ddcutil|getvcp' "$script"; then
  printf 'sunshine-mode must not depend on DDC/CI input-source state\n' >&2
  exit 1
fi

if rg -Fq '"${real_output},disable"' "$script"; then
  printf 'sunshine-mode must never disable the real desktop output\n' >&2
  exit 1
fi

if ! rg -Fq 'dummy_rule="${HYPR_DUMMY_RULE:-${dummy_output},3840x2160@60,auto,1}"' "$script"; then
  printf 'streaming mode must enable the dummy at 3840x2160@60, auto-placed, scale 1\n' >&2
  exit 1
fi

if ! rg -q 'until output_active "\$dummy_output"' "$script"; then
  printf 'start must wait for the dummy output before Sunshine begins capture\n' >&2
  exit 1
fi

if ! rg -q 'moveworkspacetomonitor "\$workspace \$real_output"' "$script"; then
  printf 'stop must move workspaces from the dummy back to the real output\n' >&2
  exit 1
fi

if ! rg -q 'if output_active "\$real_output"; then' "$script"; then
  printf 'stop must not disable the dummy when it is the only active output\n' >&2
  exit 1
fi

printf 'sunshine-mode tests passed\n'
