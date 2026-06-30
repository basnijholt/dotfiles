# GitOps continuous deployment with comin
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cominWatchdog = pkgs.writeShellScript "comin-watchdog" ''
    set -euo pipefail

    endpoint="http://127.0.0.1:4243/metrics"
    state="$STATE_DIRECTORY/last-fetch-count"

    metrics="$(${pkgs.curl}/bin/curl -fsS --max-time 10 "$endpoint" 2>/dev/null || true)"
    if [ -z "$metrics" ]; then
      echo "comin metrics are unreachable at $endpoint"
      exit 1
    fi

    failed="$(printf '%s\n' "$metrics" | ${pkgs.gawk}/bin/awk '$1 ~ /^comin_last_.*_failed/ && $NF != 0 { print; exit }')"
    if [ -n "$failed" ]; then
      echo "comin reports failure: $failed"
      exit 1
    fi

    suspended="$(printf '%s\n' "$metrics" | ${pkgs.gawk}/bin/awk '$1 == "comin_is_suspended" { print $NF; exit }')"
    if [ "''${suspended:-0}" = "1" ]; then
      echo "comin is suspended; skipping progress check"
      exit 0
    fi

    current="$(printf '%s\n' "$metrics" | ${pkgs.gawk}/bin/awk '$1 ~ /^comin_fetch_count/ && $0 ~ /status="succeeded"/ { print int($NF); exit }')"
    previous="$(${pkgs.coreutils}/bin/cat "$state" 2>/dev/null || true)"
    if [ -z "$current" ]; then
      echo "could not read comin_fetch_count from metrics"
      exit 1
    fi

    printf '%s\n' "$current" > "$state"
    if [ -n "$previous" ] && [ "$current" = "$previous" ]; then
      echo "comin fetch_count stuck at $current"
      exit 1
    fi

    echo "comin OK: fetch_count=$current, previous=''${previous:-none}"
  '';
in
{
  services.comin = {
    enable = true;
    exporter.listen_address = "127.0.0.1";
    # Do not enable services.comin.submodules here. That makes Nix evaluate the
    # flake with ?submodules=1, which tries to fetch private git@github.com
    # submodules from comin's root context and fails without a deploy SSH key.
    remotes = [
      {
        name = "origin";
        url = "https://github.com/basnijholt/dotfiles.git";
        branches.main.name = "main";
      }
    ];
    repositorySubdir = "configs/nixos";
    hostname = config.networking.hostName;
  };

  # Fix diverged history on comin start (e.g., after force-push)
  # Use || true to tolerate network unavailability at boot - comin will fetch on its own
  systemd.services = lib.mkIf config.services.comin.enable {
    # comin must restart when its own config changes. Otherwise a bad running
    # config can keep failing before it ever deploys the commit that fixes it.
    comin.restartIfChanged = lib.mkForce true;

    comin.preStart = ''
      REPO="/var/lib/comin/repository"
      if [ -d "$REPO/.git" ]; then
        ${pkgs.git}/bin/git -C "$REPO" fetch origin || true
        ${pkgs.git}/bin/git -C "$REPO" reset --hard origin/main || true
      fi
    '';

    # comin can stay systemd-active while a saturated machine prevents it from
    # making progress. Watch metrics progress instead of only service state.
    comin-watchdog = {
      description = "Check that comin is still polling and reporting healthy deploys";
      wants = [ "comin.service" ];
      after = [ "comin.service" ];
      script = ''
        exec ${cominWatchdog}
      '';
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "comin-watchdog";
      };
    };
  };

  systemd.timers.comin-watchdog = lib.mkIf config.services.comin.enable {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";
      Persistent = true;
      RandomizedDelaySec = "2m";
    };
  };
}
