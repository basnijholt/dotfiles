{ config, lib, pkgs, ... }:

let
  ntfyUrl = "http://192.168.1.2:8089/nas-alerts";
  ntfyPriority = "high";

  nasHealthAlert = pkgs.writeShellScriptBin "nas-health-alert" ''
    set -euo pipefail

    subject="NAS health alert"
    args=()

    while [ "$#" -gt 0 ]; do
      case "$1" in
        -s)
          subject="''${2:-$subject}"
          shift 2
          ;;
        *)
          args+=("$1")
          shift
          ;;
      esac
    done

    body=""
    if [ -n "''${SMARTD_MESSAGE:-}" ]; then
      subject="''${SMARTD_SUBJECT:-SMARTD alert on nas}"
      body="$SMARTD_MESSAGE"
    fi

    stdin=""
    if ! [ -t 0 ]; then
      stdin="$(${pkgs.coreutils}/bin/cat || true)"
    fi
    if [ -n "$stdin" ]; then
      body="''${body:+$body

}$stdin"
    fi
    if [ "''${#args[@]}" -gt 0 ]; then
      body="''${body:+$body

}alert arguments: ''${args[*]}"
    fi
    if [ -z "$body" ]; then
      body="NAS health alert hook invoked without a message body."
    fi

    summary="$(printf '%s' "$body" | ${pkgs.coreutils}/bin/tr '\n' ' ' | ${pkgs.coreutils}/bin/cut -c1-500)"
    ${pkgs.util-linux}/bin/logger -t nas-health-alert -- "$subject: $summary"
    printf '%s\n\n%s\n' "$subject" "$body" | ${pkgs.util-linux}/bin/wall || true

    ${pkgs.curl}/bin/curl \
      --fail \
      --silent \
      --show-error \
      --max-time 10 \
      -H "Title: $subject" \
      -H ${lib.escapeShellArg "Priority: ${ntfyPriority}"} \
      --data-binary "$body" \
      ${lib.escapeShellArg ntfyUrl} >/dev/null \
      || ${pkgs.util-linux}/bin/logger -t nas-health-alert -- "failed to send ntfy alert"
  '';

  alertFailedUnit = pkgs.writeShellScript "nas-health-alert-failed-unit" ''
    set -euo pipefail

    unit="''${1:-unknown-unit}"
    {
      echo "Unit failed: $unit"
      echo
      ${pkgs.systemd}/bin/systemctl status --no-pager --full "$unit" || true
      echo
      ${pkgs.systemd}/bin/journalctl -u "$unit" -n 120 --no-pager || true
    } | ${nasHealthAlert}/bin/nas-health-alert -s "NAS unit failed: $unit"
  '';

  incus = "${config.virtualisation.incus.package}/bin/incus";

  b2BackupWatchdog = pkgs.writeShellScript "nas-b2-backup-watchdog" ''
    set -euo pipefail

    container="nixos"
    unit="rclone-b2-backup.service"
    max_age_hours=36

    if ! ${incus} info "$container" >/dev/null 2>&1; then
      echo "MISSING B2 backup container: Incus container $container is not reachable"
      exit 1
    fi

    for source in /mnt/tank/backups/ssd/docker/stacks /mnt/tank/backups/ssd/docker/data; do
      if ! ${incus} exec "$container" -- /run/current-system/sw/bin/test -d "$source"; then
        echo "MISSING B2 backup source: $container:$source"
        exit 1
      fi
    done

    result="$(${incus} exec "$container" -- /run/current-system/sw/bin/systemctl show "$unit" -p Result --value --no-pager)"
    status="$(${incus} exec "$container" -- /run/current-system/sw/bin/systemctl show "$unit" -p ExecMainStatus --value --no-pager)"
    timestamp="$(${incus} exec "$container" -- /run/current-system/sw/bin/systemctl show "$unit" -p ExecMainExitTimestamp --value --no-pager)"

    if [ "$result" != "success" ] || [ "$status" != "0" ]; then
      echo "STALE B2 backup: $unit last result=$result status=$status"
      exit 1
    fi

    if [ -z "$timestamp" ]; then
      echo "STALE B2 backup: $unit has no recorded successful exit timestamp"
      exit 1
    fi

    now="$(${pkgs.coreutils}/bin/date +%s)"
    last="$(${pkgs.coreutils}/bin/date -d "$timestamp" +%s)"
    age_hours=$(( (now - last) / 3600 ))

    if [ "$age_hours" -gt "$max_age_hours" ]; then
      echo "STALE B2 backup: $unit last succeeded at $timestamp, ''${age_hours}h ago; limit is ''${max_age_hours}h"
      exit 1
    fi

    echo "OK B2 backup: $unit last succeeded at $timestamp, ''${age_hours}h ago; limit is ''${max_age_hours}h"
  '';
in
{
  power.ups.upsmon.monitor.cyberpower.system = lib.mkForce "cyberpower@192.168.1.3:3493";

  services.smartd = {
    enable = true;
    autodetect = true;
    defaults.autodetected = "-a -o on -S on -s (S/../../7/00) -m root -M exec ${nasHealthAlert}/bin/nas-health-alert";
    notifications = {
      mail.enable = false;
      wall.enable = true;
    };
  };

  services.zfs.zed.settings = {
    ZED_EMAIL_ADDR = [ "root" ];
    ZED_EMAIL_PROG = "${nasHealthAlert}/bin/nas-health-alert";
    ZED_EMAIL_OPTS = "-s '@SUBJECT@' @ADDRESS@";
    ZED_NOTIFY_INTERVAL_SECS = 3600;
    ZED_NOTIFY_VERBOSE = true;
  };

  services.netdata = {
    enable = true;
    enableAnalyticsReporting = false;
    extraNdsudoPackages = with pkgs; [
      nvme-cli
      smartmontools
    ];
    config.web."bind to" = "127.0.0.1";
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
    };
    smartctl = {
      enable = true;
      maxInterval = "60s";
    };
    zfs = {
      enable = true;
      pools = [
        "ssd"
        "tank"
      ];
    };
    nut = {
      enable = true;
      nutServer = "192.168.1.3";
    };
  };

  systemd.services."nas-health-alert@" = {
    description = "Send NAS health alert for failed unit %I";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${alertFailedUnit} %I";
    };
  };

  systemd.services.nas-b2-backup-watchdog = {
    description = "Check Backblaze B2 rclone backup freshness";
    after = [ "incus.service" ];
    unitConfig.OnFailure = [ "nas-health-alert@%n.service" ];
    script = ''
      exec ${b2BackupWatchdog}
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.nas-b2-backup-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };

  environment.systemPackages = [ nasHealthAlert ];
}
