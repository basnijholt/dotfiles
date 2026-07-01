#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
script="$script_dir/auto-monitor-profile.sh"

assert_profile() {
  local expected="$1"
  local json="$2"
  local actual

  actual="$(printf '%s\n' "$json" | env HYPR_SKIP_DDC=1 "$script" --profile-from-json)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected profile %s, got %s\n' "$expected" "$actual" >&2
    return 1
  fi
}

assert_profile_with_input() {
  local expected="$1"
  local input_source="$2"
  local json="$3"
  local actual

  actual="$(printf '%s\n' "$json" | env HYPR_REAL_INPUT_SOURCE_CURRENT="$input_source" "$script" --profile-from-json)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected profile %s, got %s\n' "$expected" "$actual" >&2
    return 1
  fi
}

assert_profile real '[{"name":"HDMI-A-1","disabled":false},{"name":"DP-1","disabled":false}]'
assert_profile dummy '[{"name":"HDMI-A-1","disabled":false}]'
assert_profile dummy '[{"name":"HDMI-A-1","disabled":false},{"name":"DP-1","disabled":true}]'
assert_profile_with_input real 0x0f '[{"name":"HDMI-A-1","disabled":false},{"name":"DP-1","disabled":false}]'
assert_profile_with_input dummy 0x19 '[{"name":"HDMI-A-1","disabled":false},{"name":"DP-1","disabled":false}]'

printf 'auto-monitor-profile tests passed\n'
