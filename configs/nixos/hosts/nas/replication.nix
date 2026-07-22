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
  hetznerMatrixReplicationKey = "/etc/ssh/nas-replication-hetzner-matrix-ed25519";

  hetznerSaasKey = "/etc/ssh/nas-replication-hetzner-saas-ed25519";

  # hetzner-saas, via its tailnet IP since the 2026-07 ZFS reinstall put it
  # on the common stack; the from= pin in root's authorized_keys there is
  # the NAS's stable tailnet IP (100.64.0.1). The k3s state tarball pull
  # remains until the follow-up switch to a syncoid pull of zroot/var.
  hetznerSaasHost = "100.64.0.2";

  # hetzner-matrix (mindroom.chat), via its tailnet IP. Both ends have stable
  # tailscale addresses, so the from= pin in root's authorized_keys there is
  # the NAS's tailnet IP (100.64.0.1) and survives home WAN IP changes. A
  # DDNS name cannot serve as that pin: sshd from= matches the connecting
  # IP's reverse DNS, never a forward lookup. If the server is recreated and
  # rejoins the tailnet as a new node, update this IP and the remote pin.
  hetznerMatrixHost = "100.64.0.36";

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
    {
      label = "hetzner-matrix outbound replication key";
      path = hetznerMatrixReplicationKey;
    }
    {
      label = "hetzner-saas outbound backup key";
      path = hetznerSaasKey;
    }
  ];

  # File-based backups that are neither ZFS datasets nor restic repos: watch
  # the newest dump file's age. 48h absorbs one missed nightly run.
  watchedDumpDirs = [
    {
      label = "hetzner-saas k3s state dump";
      path = "/mnt/tank/backups/hetzner-saas";
      maxAgeHours = 48;
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
    # Watch the hetzner-matrix children separately: both come from the same
    # pull job, but a per-dataset check keeps a fresh var snapshot from
    # masking a stale tuwunel one (or vice versa).
    {
      label = "hetzner-matrix tuwunel";
      dataset = "tank/backups/hetzner-matrix/tuwunel";
      maxAgeHours = 48;
    }
    {
      label = "hetzner-matrix var";
      dataset = "tank/backups/hetzner-matrix/var";
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

  watchdogDumpChecks = pkgs.lib.concatMapStringsSep "\n" (entry: ''
    check_dump ${pkgs.lib.escapeShellArg entry.label} ${pkgs.lib.escapeShellArg entry.path} ${toString entry.maxAgeHours}
  '') watchedDumpDirs;

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

      # With -t snapshot, -d 1 lists only this dataset's own snapshots (child
      # datasets sit at depth 1, so their snapshots are at depth 2; verified
      # live on the nas). The exact prefix match below keeps a fresh child
      # autosnap from masking a stale root even if that depth behavior ever
      # changes, instead of relying on it.
      latest="$(
        zfs list -H -p -t snapshot -d 1 -o creation,name -s creation "$dataset" 2>/dev/null \
          | ${pkgs.gawk}/bin/awk -v prefix="$dataset@autosnap_" 'index($2, prefix) == 1' \
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

    check_dump() {
      label="$1"
      dump_dir="$2"
      max_age_hours="$3"

      if [ ! -d "$dump_dir" ]; then
        echo "MISSING $label: $dump_dir does not exist"
        failed=1
        return
      fi

      latest_epoch="$(
        ${pkgs.findutils}/bin/find "$dump_dir" -maxdepth 1 -type f -name '*.tar.gz' -printf '%T@\n' 2>/dev/null \
          | ${pkgs.coreutils}/bin/sort -n \
          | ${pkgs.coreutils}/bin/tail -n 1 \
          | ${pkgs.coreutils}/bin/cut -d . -f 1 \
          || true
      )"

      if [ -z "$latest_epoch" ]; then
        echo "STALE $label: no dump files in $dump_dir"
        failed=1
        return
      fi

      age_hours=$(( (now - latest_epoch) / 3600 ))

      if [ "$age_hours" -gt "$max_age_hours" ]; then
        echo "STALE $label: newest dump is ''${age_hours}h old; limit is ''${max_age_hours}h"
        failed=1
        return
      fi

      echo "OK $label: newest dump is ''${age_hours}h old; limit is ''${max_age_hours}h"
    }

    ${watchdogChecks}
    ${watchdogAutosnapChecks}
    ${watchdogKeyChecks}
    ${watchdogResticChecks}
    ${watchdogDumpChecks}

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

      # Nothing on the nuc prunes this mirror's replicated autosnap_*
      # snapshots (nuc's sanoid deliberately excludes zroot/backups), so
      # trim it to the source's retention here — without this the mirror
      # accumulates every ssd snapshot forever, the same bug the hetzner
      # pull had.
      syncoid ${mkSyncoidSsdArgs} \
        --delete-target-snapshots \
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

      # Trim the target to the source's snapshot set, like the hp/nuc/pi4
      # push jobs do. This also cleans up the legacy zfs-auto-snap_*
      # snapshots that accumulated before the 2026-07 sanoid migration,
      # which no prune policy ever matched.
      # Pull over the tailnet (hetzner = 100.64.0.32) so the from= pin in
      # its authorized_keys is the NAS's stable tailnet IP instead of the
      # dynamic home WAN address, matching the other cloud pulls.
      syncoid ${mkSyncoidCommonArgs} \
        --delete-target-snapshots \
        --sshkey=${hetznerReplicationKey} \
        --sshport=22 \
        --sshoption=BatchMode=yes \
        --sshoption=ConnectTimeout=10 \
        root@100.64.0.32:zroot/websites tank/backups/hetzner
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

  systemd.services.nas-replicate-hetzner-matrix = {
    description = "Pull hetzner-matrix (mindroom) backups over SSH";
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
      ConditionPathExists = hetznerMatrixReplicationKey;
      OnFailure = [ "nas-health-alert@%n.service" ];
    };
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list tank/backups/hetzner-matrix >/dev/null

      # zroot/tuwunel is the Matrix RocksDB; zroot/var holds the mautrix
      # bridge state and secrets under /var/lib. The rest of zroot (root,
      # nix, home) is rebuildable from this repo.
      # --delete-target-snapshots keeps the mirror matched to the source's
      # retention and cleans up legacy zfs-auto-snap_* snapshots from
      # before the 2026-07 sanoid migration.
      for dataset in tuwunel var; do
        syncoid ${mkSyncoidCommonArgs} \
          --delete-target-snapshots \
          --sshkey=${hetznerMatrixReplicationKey} \
          --sshport=22 \
          --sshoption=BatchMode=yes \
          --sshoption=ConnectTimeout=10 \
          root@${hetznerMatrixHost}:zroot/"$dataset" tank/backups/hetzner-matrix/"$dataset"
      done
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-replicate-hetzner-matrix = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:55:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.nas-backup-hetzner-saas = {
    description = "Pull hetzner-saas k3s state tarball over SSH";
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
      ConditionPathExists = hetznerSaasKey;
      OnFailure = [ "nas-health-alert@%n.service" ];
    };
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list tank/backups/hetzner-saas >/dev/null

      dump_dir=/mnt/tank/backups/hetzner-saas
      out="$dump_dir/k3s-state-$(date +%Y-%m-%d).tar.gz"
      tmp="$out.partial"

      # k3s server state (sqlite DB, join token, TLS, manifests), the
      # mindroom-saas hcloud token, and /etc/rancher. The containerd cache
      # under rancher/k3s/agent is rebuildable and huge, so it is skipped.
      # Customer PVC data lives on Hetzner Cloud Volumes via the hcloud CSI
      # and is NOT inside these paths; this dump covers cluster
      # reconstruction, not PVC contents.
      #
      # tar exits 1 for "file changed as we read it" (live sqlite writes);
      # accept that, fail on anything worse.
      ssh -i ${hetznerSaasKey} \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        root@${hetznerSaasHost} \
        'tar czf - --warning=no-file-changed -C / var/lib/rancher/k3s/server var/lib/mindroom-saas etc/rancher' \
        > "$tmp" || [ "$?" -eq 1 ]

      test -s "$tmp"
      mv "$tmp" "$out"

      ${pkgs.findutils}/bin/find "$dump_dir" -maxdepth 1 -name 'k3s-state-*.tar.gz' -mtime +30 -delete
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "1h";
    };
  };

  systemd.timers.nas-backup-hetzner-saas = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 01:05:00";
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
