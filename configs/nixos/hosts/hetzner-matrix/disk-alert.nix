# ntfy alert when the zroot pool runs low on space.
#
# On 2026-10-05 the pool filled up while Tuwunel was writing, which left a torn
# WAL record that hung every later startup until the database was restored from
# a snapshot. This timer warns well before that point.
#
# ntfy runs on docker-lxc; the headscale ACL lets hetzner-matrix reach
# docker:8089 over the tailnet. The `homelab` topic is the one Uptime Kuma uses.
{ config, pkgs, ... }:

let
  zfs = config.boot.zfs.package;
  pool = "zroot";
  ntfyUrl = "http://100.64.0.28:8089/homelab";
  # GiB of free space below which to warn (high priority) and page (urgent).
  warnGiB = 8;
  critGiB = 3;
  # While still low, repeat the alert this often.
  repeatSeconds = 6 * 3600;

  diskAlert = pkgs.writeShellScript "disk-space-alert" ''
    set -euo pipefail

    gib=$((1024 * 1024 * 1024))
    avail="$(${zfs}/bin/zfs list -Hp -o avail ${pool})"
    used="$(${zfs}/bin/zfs list -Hp -o used ${pool})"
    total=$((avail + used))
    free_pct=$((avail * 100 / total))
    free_gib="$(${pkgs.gawk}/bin/awk -v a="$avail" -v g="$gib" 'BEGIN { printf "%.1f", a / g }')"
    total_gib="$(${pkgs.gawk}/bin/awk -v a="$total" -v g="$gib" 'BEGIN { printf "%.0f", a / g }')"

    if [ "$avail" -lt $((${toString critGiB} * gib)) ]; then
      level=crit
    elif [ "$avail" -lt $((${toString warnGiB} * gib)) ]; then
      level=warn
    else
      level=ok
    fi

    state="$STATE_DIRECTORY/state"
    last_level=ok
    last_sent=0
    if [ -f "$state" ]; then
      read -r last_level last_sent < "$state" || true
    fi
    now="$(${pkgs.coreutils}/bin/date +%s)"

    send=0
    if [ "''${1:-}" = "--test" ]; then
      send=1
      title="TEST: ${config.networking.hostName} disk alert"
      priority=default
      tags=test_tube
    elif [ "$level" != "$last_level" ]; then
      send=1
    elif [ "$level" != ok ] && [ $((now - last_sent)) -ge ${toString repeatSeconds} ]; then
      send=1
    fi

    if [ "''${1:-}" != "--test" ]; then
      case "$level" in
        crit) title="${config.networking.hostName}: disk almost full"; priority=urgent; tags=rotating_light ;;
        warn) title="${config.networking.hostName}: disk space low"; priority=high; tags=warning ;;
        ok) title="${config.networking.hostName}: disk space recovered"; priority=low; tags=white_check_mark ;;
      esac
    fi

    echo "${pool}: $free_gib GiB free of $total_gib GiB ($free_pct%), level=$level"
    if [ "$send" = 1 ]; then
      body="$(printf '%s\n\n%s\n' \
        "${pool}: $free_gib GiB free of $total_gib GiB ($free_pct%)." \
        "$(${zfs}/bin/zfs list -o name,used,usedbysnapshots,avail -d 1 ${pool})")"
      if ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 10 \
        -H "Title: $title" -H "Priority: $priority" -H "Tags: $tags" \
        --data-binary "$body" ${ntfyUrl} >/dev/null; then
        [ "''${1:-}" = "--test" ] || echo "$level $now" > "$state"
      else
        echo "failed to send ntfy alert" >&2
      fi
    else
      # Keep the level current without resetting the repeat timer.
      echo "$level $last_sent" > "$state"
    fi
  '';
in
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "disk-space-alert-test" ''
      exec ${pkgs.systemd}/bin/systemd-run --wait --collect --property=StateDirectory=disk-space-alert ${diskAlert} --test
    '')
  ];

  systemd.services.disk-space-alert = {
    description = "ntfy alert when ${pool} runs low on space";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = diskAlert;
      StateDirectory = "disk-space-alert";
    };
  };

  systemd.timers.disk-space-alert = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      Persistent = true;
    };
  };
}
