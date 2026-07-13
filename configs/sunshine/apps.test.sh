#!/usr/bin/env bash
set -euo pipefail

config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
apps_json="$config_dir/apps.json"

jq empty "$apps_json"

if rg -q 'gnome-monitor-config|xrandr' "$apps_json"; then
  printf 'apps.json must not use GNOME/X11 monitor prep commands under Hyprland\n' >&2
  exit 1
fi

jq -e '
  def app($name): .apps[] | select(.name == $name);

  (app("Desktop").output_name == "HDMI-A-1")
  and (app("Steam Big Picture").output_name == "HDMI-A-1")
  and (app("Steam Big Picture").detached == ["setsid steam steam://open/bigpicture"])
  and (app("Steam Big Picture")."prep-cmd" == [{"do": "", "undo": "setsid steam steam://close/bigpicture"}])
' "$apps_json" >/dev/null

printf 'sunshine apps tests passed\n'
