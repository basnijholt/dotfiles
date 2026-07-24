# GitOps continuous deployment with comin
{
  config,
  lib,
  pkgs,
  ...
}:

let
  sshKeys = import ./ssh-keys.nix;

  cominAllowedSigners = pkgs.writeText "comin-allowed-signers" ''
    bas@nijho.lt namespaces="git" ${sshKeys.userKeys.bas}
  '';

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

    # Fetch progress alone cannot see a wedge: fetch_count keeps advancing
    # on a host whose builder never runs (corrupt local clone, stale binary,
    # unsigned tip). Also require that a tip that has been public for a
    # while appears somewhere in comin's own status: the Fetcher line proves
    # it was fetched and signature-verified, Builder/Deployer lines prove it
    # was evaluated or switched to. All observed wedges fail all three.
    repo="/var/lib/comin/repository"
    comin_bin="/run/current-system/sw/bin/comin"
    lag_max_hours=48
    if [ -d "$repo" ] && [ -x "$comin_bin" ]; then
      tip="$(${pkgs.git}/bin/git -C "$repo" rev-parse origin/main 2>/dev/null || true)"
      tip_epoch="$(${pkgs.git}/bin/git -C "$repo" log -1 --format=%ct origin/main 2>/dev/null || true)"
      if [ -z "$tip" ] || [ -z "$tip_epoch" ]; then
        # An existing clone whose origin/main cannot be read is itself a
        # wedge (corrupt packs made signature verification fail for weeks
        # on one host); recovery: stop comin, remove the repository
        # directory, start comin — it re-clones.
        echo "comin clone at $repo exists but origin/main is unreadable"
        exit 1
      fi
      tip_age_hours=$(( ($(${pkgs.coreutils}/bin/date +%s) - tip_epoch) / 3600 ))
      if [ "$tip_age_hours" -gt "$lag_max_hours" ]; then
        known="$("$comin_bin" status 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oE 'Commit (ID )?[0-9a-f]{7,}' | ${pkgs.gawk}/bin/awk '{ print $NF }' || true)"
        if ! printf '%s\n' "$known" | ${pkgs.gnugrep}/bin/grep -qx "$tip"; then
          echo "comin lag: origin/main tip $tip is ''${tip_age_hours}h old but was never verified, built, or deployed"
          exit 1
        fi
      fi
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
    sshAllowedSignersPath = "${cominAllowedSigners}";
  };

  # Refresh comin's bare repository on start. This is best-effort because comin
  # performs its own fetches and intentionally treats force-pushed history as an
  # operator decision, not something to accept automatically.
  systemd.services = lib.mkIf config.services.comin.enable {
    # Keep comin's self-update behavior conservative. If switch-to-configuration
    # stops comin while comin is running that switch, the deploy can succeed but
    # leave the agent inactive.

    comin.preStart = ''
      REPO="/var/lib/comin/repository"
      if [ -d "$REPO" ]; then
        ${pkgs.git}/bin/git -C "$REPO" fetch --prune origin || true
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
