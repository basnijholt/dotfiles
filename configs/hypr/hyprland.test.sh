#!/usr/bin/env bash
set -euo pipefail

config_file="${1:-configs/hypr/hyprland.conf}"

if ! rg -q '^[[:space:]]*on_focus_under_fullscreen = 0$' "$config_file"; then
  printf 'Hyprland must ignore focus requests under fullscreen windows\n' >&2
  exit 1
fi

if rg -q 'auto-monitor-profile' "$config_file"; then
  printf 'Hyprland must not autostart the DDC monitor poller\n' >&2
  exit 1
fi

if ! rg -q '^monitor=HDMI-A-1,disable$' "$config_file"; then
  printf 'the HDMI dummy plug must be disabled outside Sunshine streaming\n' >&2
  exit 1
fi
