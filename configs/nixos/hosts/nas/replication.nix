{ pkgs, ... }:

let
  replicationPath = with pkgs; [
    coreutils
    gawk
    gnugrep
    lz4
    lzop
    mbuffer
    openssh
    sanoid
    zfs
  ];

  syncoidCommon = [
    "--recursive"
    "--compress=lz4"
  ];

  mkSyncoidArgs = pkgs.lib.escapeShellArgs syncoidCommon;

  watchedBackupDatasets = [
    {
      label = "local ssd mirror";
      dataset = "tank/backups/ssd";
      maxAgeHours = 36;
    }
    {
      label = "hp inbound push";
      dataset = "tank/backups/hp";
      maxAgeHours = 48;
    }
    {
      label = "nuc inbound push";
      dataset = "tank/backups/nuc";
      maxAgeHours = 48;
    }
    {
      label = "pi4 inbound push";
      dataset = "tank/backups/pi4";
      maxAgeHours = 48;
    }
    {
      label = "hetzner websites";
      dataset = "tank/backups/hetzner";
      maxAgeHours = 48;
    }
  ];

  watchdogChecks = pkgs.lib.concatMapStringsSep "\n" (entry: ''
    check_dataset ${pkgs.lib.escapeShellArg entry.label} ${pkgs.lib.escapeShellArg entry.dataset} ${toString entry.maxAgeHours}
  '') watchedBackupDatasets;

  replicationWatchdog = pkgs.writeShellScript "nas-replication-watchdog" ''
    set -euo pipefail

    now="$(${pkgs.coreutils}/bin/date +%s)"
    failed=0

    check_dataset() {
      label="$1"
      dataset="$2"
      max_age_hours="$3"

      if ! zfs list -H -o name "$dataset" >/dev/null 2>&1; then
        echo "MISSING $label: $dataset does not exist"
        failed=1
        return
      fi

      latest="$(
        zfs list -H -p -t snapshot -r -o creation,name -s creation "$dataset" 2>/dev/null \
          | ${pkgs.coreutils}/bin/tail -n 1 \
          || true
      )"

      if [ -z "$latest" ]; then
        echo "STALE $label: no snapshots under $dataset"
        failed=1
        return
      fi

      latest_epoch="$(printf '%s\n' "$latest" | ${pkgs.gawk}/bin/awk '{ print $1 }')"
      latest_snapshot="$(printf '%s\n' "$latest" | ${pkgs.gawk}/bin/awk '{ print $2 }')"
      age_hours=$(( (now - latest_epoch) / 3600 ))

      if [ "$age_hours" -gt "$max_age_hours" ]; then
        echo "STALE $label: newest snapshot $latest_snapshot is ''${age_hours}h old; limit is ''${max_age_hours}h"
        failed=1
        return
      fi

      echo "OK $label: newest snapshot $latest_snapshot is ''${age_hours}h old; limit is ''${max_age_hours}h"
    }

    ${watchdogChecks}

    if [ "$failed" -ne 0 ]; then
      exit 1
    fi
  '';
in
{
  environment.systemPackages = with pkgs; [
    sanoid
    lz4
    lzop
    mbuffer
  ];

  # Existing NixOS hosts push Syncoid backups as root. Keep the shared default
  # root-login denial, but allow key-only root SSH from the LAN for replication.
  # Install source host keys at cutover in /etc/ssh/authorized_keys.d/root with
  # from= restrictions; do not commit those keys to the public repo.
  services.openssh.extraConfig = ''
    Match User root Address 192.168.1.0/24
      PermitRootLogin prohibit-password
  '';

  systemd.services.nas-replicate-ssd-local = {
    description = "Replicate local ssd pool into tank backup dataset";
    wants = [ "zfs.target" ];
    after = [ "zfs.target" ];
    unitConfig.OnFailure = [ "nas-health-alert@%n.service" ];
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list ssd >/dev/null
      zfs list tank/backups/ssd >/dev/null

      syncoid ${mkSyncoidArgs} ssd tank/backups/ssd
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-replicate-ssd-local = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.nas-replicate-ssd-to-nuc = {
    description = "Replicate ssd pool to NUC over SSH";
    wants = [
      "network-online.target"
      "zfs.target"
    ];
    after = [
      "network-online.target"
      "zfs.target"
    ];
    unitConfig = {
      ConditionPathExists = "/etc/ssh/nas-replication-nuc-ed25519";
      OnFailure = [ "nas-health-alert@%n.service" ];
    };
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list ssd >/dev/null

      syncoid ${mkSyncoidArgs} \
        --sshkey=/etc/ssh/nas-replication-nuc-ed25519 \
        --sshport=22 \
        --sshoption=BatchMode=yes \
        --sshoption=ConnectTimeout=10 \
        ssd root@192.168.1.2:zroot/backups
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-replicate-ssd-to-nuc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:35:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.nas-replicate-hetzner-websites = {
    description = "Pull Hetzner website backups over SSH";
    wants = [
      "network-online.target"
      "zfs.target"
    ];
    after = [
      "network-online.target"
      "zfs.target"
    ];
    unitConfig = {
      ConditionPathExists = "/etc/ssh/nas-replication-hetzner-ed25519";
      OnFailure = [ "nas-health-alert@%n.service" ];
    };
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list tank/backups/hetzner >/dev/null

      syncoid ${mkSyncoidArgs} \
        --sshkey=/etc/ssh/nas-replication-hetzner-ed25519 \
        --sshport=22 \
        --sshoption=BatchMode=yes \
        --sshoption=ConnectTimeout=10 \
        root@46.224.10.245:zroot/websites tank/backups/hetzner
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-replicate-hetzner-websites = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:45:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.nas-replication-watchdog = {
    description = "Check NAS replication snapshot freshness";
    wants = [ "zfs.target" ];
    after = [ "zfs.target" ];
    unitConfig.OnFailure = [ "nas-health-alert@%n.service" ];
    path = replicationPath;
    script = ''
      exec ${replicationWatchdog}
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.nas-replication-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };
}
