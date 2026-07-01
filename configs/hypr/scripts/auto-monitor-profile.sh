#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -d "$XDG_RUNTIME_DIR/hypr" ]]; then
  hypr_instance_dir="$(find "$XDG_RUNTIME_DIR/hypr" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
  if [[ -n "$hypr_instance_dir" ]]; then
    export HYPRLAND_INSTANCE_SIGNATURE="${hypr_instance_dir##*/}"
  fi
fi

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  export WAYLAND_DISPLAY="wayland-1"
fi

real_output="${HYPR_REAL_OUTPUT:-DP-1}"
dummy_output="${HYPR_DUMMY_OUTPUT:-HDMI-A-1}"

real_rule="${HYPR_REAL_RULE:-${real_output},5120x2160@120,0x0,1.666667}"
dummy_rule="${HYPR_DUMMY_RULE:-${dummy_output},4096x2160@59.94,0x0,1.6}"
real_input_source="${HYPR_REAL_INPUT_SOURCE:-0x0f}"
real_ddc_bus="${HYPR_DDC_BUS:-}"
poll_interval="${HYPR_MONITOR_POLL_INTERVAL:-5}"
ddc_bus_cache="${HYPR_DDC_BUS_CACHE:-${XDG_RUNTIME_DIR:-/tmp}/auto-monitor-profile-${real_output}.ddc-bus}"

usage() {
  cat <<EOF
Usage: ${0##*/} [--watch|--once|--profile-from-json]

Automatically use ${real_output} when it is available, otherwise use the
${dummy_output} dummy plug for Sunshine.

If DDC/CI is available through ddcutil, ${real_output} is considered active
only when the monitor reports input source ${real_input_source}. For VCP 0x60,
0x0f is commonly DisplayPort-1. If DDC is unavailable or unreadable, the script
falls back to Hyprland connection state. The script resolves and caches the DDC
bus for ${real_output}; set HYPR_DDC_BUS to override it.

Options:
  --watch              Apply once, then poll for monitor/input changes.
  --once               Apply the profile once and exit.
  --profile-from-json  Read 'hyprctl monitors all -j' JSON from stdin and
                       print 'real' or 'dummy'. Intended for tests.
EOF
}

profile_from_json() {
  local json
  local real_connected
  local current_input

  json="$(cat)"
  real_connected="$(
    jq -r --arg real_output "$real_output" '
      any(.[]; .name == $real_output and (.disabled | not))
    ' <<<"$json"
  )"

  if [[ "$real_connected" != true ]]; then
    printf 'dummy\n'
    return
  fi

  current_input="$(current_real_input_source || true)"
  if [[ -n "$current_input" && "${current_input,,}" != "${real_input_source,,}" ]]; then
    printf 'dummy\n'
    return
  fi

  printf 'real\n'
}

current_real_input_source() {
  local output
  local value
  local bus
  local ddc_args=()

  if [[ -n "${HYPR_REAL_INPUT_SOURCE_CURRENT+x}" ]]; then
    printf '%s\n' "$HYPR_REAL_INPUT_SOURCE_CURRENT"
    return
  fi

  if [[ "${HYPR_SKIP_DDC:-0}" == 1 ]] || ! command -v ddcutil >/dev/null 2>&1; then
    return 1
  fi

  if [[ -n "${HYPR_DDC_DISPLAY:-}" ]]; then
    ddc_args+=(--display "$HYPR_DDC_DISPLAY")
  else
    bus="$(resolve_real_ddc_bus || true)"
    if [[ -n "$bus" ]]; then
      ddc_args+=(--bus "$bus")
    fi
  fi

  output="$(ddcutil "${ddc_args[@]}" getvcp 60 2>/dev/null || true)"
  value="$(
    grep -Eo 'sl=0x[0-9a-fA-F]+' <<<"$output" | head -n1 | sed 's/^sl=//' \
      || true
  )"

  if [[ -z "$value" ]]; then
    value="$(grep -Eo '0x[0-9a-fA-F]+' <<<"$output" | tail -n1 || true)"
  fi

  [[ -n "$value" ]] || return 1
  printf '%s\n' "${value,,}"
}

resolve_real_ddc_bus() {
  local bus

  if [[ -n "$real_ddc_bus" ]]; then
    printf '%s\n' "$real_ddc_bus"
    return
  fi

  if [[ -r "$ddc_bus_cache" ]]; then
    bus="$(<"$ddc_bus_cache")"
    if [[ -n "$bus" ]]; then
      printf '%s\n' "$bus"
      return
    fi
  fi

  bus="$(
    ddcutil detect 2>/dev/null \
      | awk -v connector="$real_output" '
          /^Display [0-9]+/ { bus = "" }
          /I2C bus:/ { bus = $NF; sub("^/dev/i2c-", "", bus) }
          /DRM_connector:/ && index($NF, "-" connector) > 0 {
            print bus
            exit
          }
        '
  )"

  [[ -n "$bus" ]] || return 1
  printf '%s\n' "$bus" >"$ddc_bus_cache"
  printf '%s\n' "$bus"
}

monitors_json() {
  hyprctl monitors all -j
}

move_workspaces_to_monitor() {
  local from_monitor="$1"
  local to_monitor="$2"

  hyprctl workspaces -j \
    | jq -r --arg from_monitor "$from_monitor" '
        .[]
        | select(.monitor == $from_monitor and .id > 0)
        | .name
      ' \
    | while IFS= read -r workspace; do
        [[ -n "$workspace" ]] || continue
        hyprctl dispatch moveworkspacetomonitor "$workspace $to_monitor" >/dev/null || true
      done
}

apply_real_profile() {
  hyprctl keyword monitor "$real_rule" >/dev/null
  move_workspaces_to_monitor "$dummy_output" "$real_output"
  hyprctl keyword monitor "${dummy_output},disable" >/dev/null
  hyprctl dispatch focusmonitor "$real_output" >/dev/null || true
}

apply_dummy_profile() {
  hyprctl keyword monitor "$dummy_rule" >/dev/null
  move_workspaces_to_monitor "$real_output" "$dummy_output"
  # Keep the real output enabled so the monitor has a live signal when it is
  # switched back to this machine. Disabling it can leave the monitor on another
  # input with no way for DDC to report DisplayPort as active again.
  hyprctl dispatch focusmonitor "$dummy_output" >/dev/null || true
}

apply_profile() {
  local profile

  profile="$(monitors_json | profile_from_json)"
  case "$profile" in
    real)
      apply_real_profile
      ;;
    dummy)
      apply_dummy_profile
      ;;
    *)
      printf 'unexpected monitor profile: %s\n' "$profile" >&2
      return 1
      ;;
  esac
}

watch_events() {
  apply_profile

  while true; do
    sleep "$poll_interval"
    apply_profile
  done
}

case "${1:---watch}" in
  --watch)
    watch_events
    ;;
  --once)
    apply_profile
    ;;
  --profile-from-json)
    profile_from_json
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
