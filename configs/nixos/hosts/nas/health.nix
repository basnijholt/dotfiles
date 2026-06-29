{ lib, pkgs, ... }:

let
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

    if [ -f /etc/nas-health-alert.env ]; then
      set -a
      # shellcheck disable=SC1091
      . /etc/nas-health-alert.env
      set +a
    fi

    if [ -n "''${NTFY_URL:-}" ]; then
      ${pkgs.curl}/bin/curl \
        --fail \
        --silent \
        --show-error \
        --max-time 10 \
        -H "Title: $subject" \
        -H "Priority: ''${NTFY_PRIORITY:-high}" \
        --data-binary "$body" \
        "$NTFY_URL" >/dev/null \
        || ${pkgs.util-linux}/bin/logger -t nas-health-alert -- "failed to send ntfy alert"
    fi
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

  environment.systemPackages = [ nasHealthAlert ];
}
