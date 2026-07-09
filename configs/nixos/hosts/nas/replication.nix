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

  syncoidSsdExcludes = [
    # Keep .ix-virt backed up: it is part of Incus recovery fidelity.
    # The nix-cache container is rebuildable and large, so skip only that
    # container dataset instead of excluding all Incus storage.
    "--exclude-datasets=^ssd/\\.ix-virt/containers/nix-cache($|/)"
  ];

  mkSyncoidArgs = extraArgs: pkgs.lib.escapeShellArgs (syncoidCommon ++ extraArgs);
  mkSyncoidCommonArgs = mkSyncoidArgs [ ];
  mkSyncoidSsdArgs = mkSyncoidArgs syncoidSsdExcludes;
  nucReceiveOptions = pkgs.lib.escapeShellArg "u o mountpoint=none o readonly=on";

  nucReplicationKey = "/etc/ssh/nas-replication-nuc-ed25519";
  hetznerReplicationKey = "/etc/ssh/nas-replication-hetzner-ed25519";

  # The outbound key files intentionally live outside this repo. Their services
  # skip via ConditionPathExists while a key is missing (e.g. after a reinstall
  # before secret staging), which never fails a unit and so never alerts. The
  # watchdog checks presence so a forgotten key becomes an alert instead of
  # silently absent replication.
  watchedReplicationKeys = [
    {
      label = "nuc outbound replication key";
      path = nucReplicationKey;
    }
    {
      label = "hetzner outbound replication key";
      path = hetznerReplicationKey;
    }
  ];

  # Syncoid creates its own sync snapshot on every run, so the backup-target
  # freshness checks stay green even if sanoid stops autosnapshotting. Check
  # the source pools for recent sanoid-named snapshots separately. Sanoid runs
  # every 10 minutes with frequent snapshots enabled, so 2 hours is generous.
  watchedAutosnapSources = [
    {
      label = "tank sanoid autosnaps";
      dataset = "tank";
      maxAgeHours = 2;
    }
    {
      label = "ssd sanoid autosnaps";
      dataset = "ssd";
      maxAgeHours = 2;
    }
  ];

  # The pc restic backup is file-based (hourly sftp push into tank/backups/pc),
  # so no dataset snapshot check can see it. Restic writes one file per
  # completed snapshot into the repo's snapshots/ directory; the newest file
  # mtime is the last successful backup. Added 2026-07-09 after finding pc's
  # backups had failed silently since 2026-03-22 on a stale repo lock —
  # nothing watched this repo. pc backs up hourly; 26h absorbs downtime.
  watchedResticRepos = [
    {
      label = "pc restic repo";
      path = "/mnt/tank/backups/pc";
      maxAgeHours = 26;
    }
  ];

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

  # Keep tank/backups/ssd mounted as a filesystem: the B2 rclone job reads
  # from this replicated mirror on purpose, instead of racing the live Docker
  # mounts while they are changing. Do not switch this mirror root to
  # mountpoint=none without moving the B2 design at the same time.

  watchdogChecks = pkgs.lib.concatMapStringsSep "\n" (entry: ''
    check_dataset ${pkgs.lib.escapeShellArg entry.label} ${pkgs.lib.escapeShellArg entry.dataset} ${toString entry.maxAgeHours}
  '') watchedBackupDatasets;

  watchdogAutosnapChecks = pkgs.lib.concatMapStringsSep "\n" (entry: ''
    check_autosnap ${pkgs.lib.escapeShellArg entry.label} ${pkgs.lib.escapeShellArg entry.dataset} ${toString entry.maxAgeHours}
  '') watchedAutosnapSources;

  watchdogKeyChecks = pkgs.lib.concatMapStringsSep "\n" (entry: ''
    check_key ${pkgs.lib.escapeShellArg entry.label} ${pkgs.lib.escapeShellArg entry.path}
  '') watchedReplicationKeys;

  watchdogResticChecks = pkgs.lib.concatMapStringsSep "\n" (entry: ''
    check_restic_repo ${pkgs.lib.escapeShellArg entry.label} ${pkgs.lib.escapeShellArg entry.path} ${toString entry.maxAgeHours}
  '') watchedResticRepos;

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

    check_autosnap() {
      label="$1"
      dataset="$2"
      max_age_hours="$3"

      # With -t snapshot, -d 1 lists only this dataset's own snapshots: child
      # datasets sit at depth 1, so their snapshots are at depth 2 and
      # excluded. A fresh child autosnap cannot mask a stale root here.
      latest="$(
        zfs list -H -p -t snapshot -d 1 -o creation,name -s creation "$dataset" 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep '@autosnap_' \
          | ${pkgs.coreutils}/bin/tail -n 1 \
          || true
      )"

      if [ -z "$latest" ]; then
        echo "STALE $label: no autosnap snapshots on $dataset"
        failed=1
        return
      fi

      latest_epoch="$(printf '%s\n' "$latest" | ${pkgs.gawk}/bin/awk '{ print $1 }')"
      latest_snapshot="$(printf '%s\n' "$latest" | ${pkgs.gawk}/bin/awk '{ print $2 }')"
      age_hours=$(( (now - latest_epoch) / 3600 ))

      if [ "$age_hours" -gt "$max_age_hours" ]; then
        echo "STALE $label: newest autosnap $latest_snapshot is ''${age_hours}h old; limit is ''${max_age_hours}h"
        failed=1
        return
      fi

      echo "OK $label: newest autosnap $latest_snapshot is ''${age_hours}h old; limit is ''${max_age_hours}h"
    }

    check_key() {
      label="$1"
      key_path="$2"

      if [ ! -f "$key_path" ]; then
        echo "MISSING $label: $key_path does not exist; its replication service is silently skipping"
        failed=1
        return
      fi

      echo "OK $label: $key_path exists"
    }

    check_restic_repo() {
      label="$1"
      repo_path="$2"
      max_age_hours="$3"

      snapshot_dir="$repo_path/snapshots"

      if [ ! -d "$snapshot_dir" ]; then
        echo "MISSING $label: $snapshot_dir does not exist"
        failed=1
        return
      fi

      latest_epoch="$(
        ${pkgs.findutils}/bin/find "$snapshot_dir" -maxdepth 1 -type f -printf '%T@\n' 2>/dev/null \
          | ${pkgs.coreutils}/bin/sort -n \
          | ${pkgs.coreutils}/bin/tail -n 1 \
          | ${pkgs.coreutils}/bin/cut -d . -f 1
      )"

      if [ -z "$latest_epoch" ]; then
        echo "STALE $label: no snapshot files in $snapshot_dir"
        failed=1
        return
      fi

      age_hours=$(( (now - latest_epoch) / 3600 ))

      if [ "$age_hours" -gt "$max_age_hours" ]; then
        echo "STALE $label: newest restic snapshot is ''${age_hours}h old; limit is ''${max_age_hours}h"
        failed=1
        return
      fi

      echo "OK $label: newest restic snapshot is ''${age_hours}h old; limit is ''${max_age_hours}h"
    }

    ${watchdogChecks}
    ${watchdogAutosnapChecks}
    ${watchdogKeyChecks}
    ${watchdogResticChecks}

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
    restartIfChanged = false;
    wants = [ "zfs.target" ];
    after = [ "zfs.target" ];
    unitConfig.OnFailure = [ "nas-health-alert@%n.service" ];
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list ssd >/dev/null
      zfs list tank/backups/ssd >/dev/null

      syncoid ${mkSyncoidSsdArgs} ssd tank/backups/ssd
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
    restartIfChanged = false;
    wants = [
      "network-online.target"
      "zfs.target"
    ];
    after = [
      "network-online.target"
      "zfs.target"
    ];
    unitConfig = {
      ConditionPathExists = nucReplicationKey;
      OnFailure = [ "nas-health-alert@%n.service" ];
    };
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list ssd >/dev/null

      syncoid ${mkSyncoidSsdArgs} \
        --recvoptions=${nucReceiveOptions} \
        --sshkey=${nucReplicationKey} \
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
    restartIfChanged = false;
    wants = [
      "network-online.target"
      "zfs.target"
    ];
    after = [
      "network-online.target"
      "zfs.target"
    ];
    unitConfig = {
      ConditionPathExists = hetznerReplicationKey;
      OnFailure = [ "nas-health-alert@%n.service" ];
    };
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list tank/backups/hetzner >/dev/null

      syncoid ${mkSyncoidCommonArgs} \
        --sshkey=${hetznerReplicationKey} \
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
    restartIfChanged = false;
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
