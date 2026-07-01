#!/usr/bin/env bash
set -euo pipefail

# Sunshine invokes this through global_prep_cmd from its user service, where
# the Hyprland session variables are not inherited.
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -d "$XDG_RUNTIME_DIR/hypr" ]]; then
  hypr_instance_dir="$(find "$XDG_RUNTIME_DIR/hypr" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
  if [[ -n "$hypr_instance_dir" ]]; then
    export HYPRLAND_INSTANCE_SIGNATURE="${hypr_instance_dir##*/}"
  fi
fi

real_output="${HYPR_REAL_OUTPUT:-DP-1}"
dummy_output="${HYPR_DUMMY_OUTPUT:-HDMI-A-1}"
# "auto" places the dummy plug next to the real output so they never overlap.
dummy_rule="${HYPR_DUMMY_RULE:-${dummy_output},3840x2160@60,auto,1}"
enable_timeout="${SUNSHINE_MODE_TIMEOUT:-10}"

usage() {
  cat <<EOF
Usage: ${0##*/} start|stop|status

Streaming-driven display switching for Sunshine on Hyprland.

${real_output} is the only desktop output; the ${dummy_output} dummy plug is
enabled only while a Sunshine session is active:

  start   Enable ${dummy_output} (${dummy_rule#"${dummy_output}",}) and wait
          until Hyprland reports it active. ${real_output} stays enabled.
  stop    Move any workspaces off ${dummy_output} back to ${real_output},
          then disable ${dummy_output}.
  status  Print 'streaming' if ${dummy_output} is active, 'normal' otherwise.

Wired into sunshine.conf as:
  global_prep_cmd do   -> start (before capture begins)
  global_prep_cmd undo -> stop  (after the session ends)
EOF
}

output_active() {
  local output="$1"

  hyprctl monitors -j | jq -e --arg output "$output" '
    any(.[]; .name == $output and (.disabled | not))
  ' >/dev/null
}

start_streaming() {
  local deadline=$((SECONDS + enable_timeout))

  hyprctl keyword monitor "$dummy_rule" >/dev/null

  until output_active "$dummy_output"; do
    if ((SECONDS >= deadline)); then
      printf '%s did not become active within %ss\n' \
        "$dummy_output" "$enable_timeout" >&2
      return 1
    fi
    sleep 0.2
  done
}

stop_streaming() {
  hyprctl workspaces -j \
    | jq -r --arg monitor "$dummy_output" '
        .[]
        | select(.monitor == $monitor and .id > 0)
        | .name
      ' \
    | while IFS= read -r workspace; do
        [[ -n "$workspace" ]] || continue
        hyprctl dispatch moveworkspacetomonitor "$workspace $real_output" >/dev/null || true
      done

  # Never disable the dummy when it is the only active output; Hyprland would
  # be left without any usable monitor.
  if output_active "$real_output"; then
    hyprctl keyword monitor "${dummy_output},disable" >/dev/null
    hyprctl dispatch focusmonitor "$real_output" >/dev/null || true
  else
    printf '%s is not active; leaving %s enabled\n' \
      "$real_output" "$dummy_output" >&2
  fi
}

status() {
  if output_active "$dummy_output"; then
    printf 'streaming\n'
  else
    printf 'normal\n'
  fi
}

case "${1:-}" in
  start)
    start_streaming
    ;;
  stop)
    stop_streaming
    ;;
  status)
    status
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
