#!/usr/bin/env bash
set -euo pipefail

config_file="${1:-configs/sunshine/sunshine.conf}"

if ! rg -q '^output_name = HDMI-A-1$' "$config_file"; then
  echo "sunshine.conf must pin capture output to HDMI-A-1" >&2
  exit 1
fi

prep_cmd="$(sed -n 's/^global_prep_cmd = //p' "$config_file")"
if [[ -z "$prep_cmd" ]]; then
  echo "sunshine.conf must define global_prep_cmd for display switching" >&2
  exit 1
fi

jq -e '
  .[0].do | endswith("sunshine-mode.sh start")
' <<<"$prep_cmd" >/dev/null || {
  echo "global_prep_cmd do must enable the dummy via sunshine-mode.sh start" >&2
  exit 1
}

jq -e '
  .[0].undo | endswith("sunshine-mode.sh stop")
' <<<"$prep_cmd" >/dev/null || {
  echo "global_prep_cmd undo must restore normal mode via sunshine-mode.sh stop" >&2
  exit 1
}

printf 'sunshine.conf tests passed\n'
