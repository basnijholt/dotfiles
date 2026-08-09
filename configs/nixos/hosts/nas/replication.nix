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
    util-linux
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
  unmountedReceiveOptions = pkgs.lib.escapeShellArg "u o mountpoint=none o readonly=on";

  nucReplicationKey = "/etc/ssh/nas-replication-nuc-ed25519";

  # The always-on LAN hosts are replicated by pull, not push: sources hold
  # no NAS credentials at all. The NAS connects to a dedicated non-root
  # user with delegated zfs send rights on each source
  # (optional/zfs-replication-source.nix), so even a fully compromised
  # source cannot reach this pool or the NAS-side snapshots protecting its
  # own backups. Keys are generated on the NAS and never leave it; the
  # addresses are router-pinned DHCP leases, static on purpose (name
  # resolution failures must not break replication).
  pullSources = {
    pc = {
      addr = "192.168.1.5";
      key = "/etc/ssh/nas-replication-pc-ed25519";
      onCalendar = "*-*-* 01:15:00";
    };
    nuc = {
      addr = "192.168.1.2";
      # Not nas-replication-nuc-ed25519: that is the legacy RSA key the
      # ssd-mirror push job uses to reach root@nuc.
      key = "/etc/ssh/nas-replication-nuc-pull-ed25519";
      onCalendar = "*-*-* 01:25:00";
    };
    hp = {
      addr = "192.168.1.3";
      key = "/etc/ssh/nas-replication-hp-ed25519";
      onCalendar = "*-*-* 01:35:00";
    };
    pi4 = {
      addr = "192.168.1.7";
      key = "/etc/ssh/nas-replication-pi4-ed25519";
      onCalendar = "*-*-* 01:45:00";
    };
  };

  # Pull one host's zroot datasets into tank/backups/<host>. home, var and
  # root are the restore set; zroot/nix is rebuildable. incus joins
  # automatically once a source grows a zroot/incus dataset.
  mkPullService = host: src: {
    description = "Pull ${host} zroot datasets over SSH";
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
      ConditionPathExists = src.key;
      OnFailure = [ "nas-health-alert@%n.service" ];
    };
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list tank/backups/${host} >/dev/null

      # --no-privilege-elevation: the remote user is non-root on purpose
      # and must never attempt sudo; its zfs rights are delegated.
      # --delete-target-snapshots keeps the mirror matched to the source's
      # retention, like every other mirror here.
      datasets="home var root"
      if ssh -i ${src.key} -o BatchMode=yes -o ConnectTimeout=10 \
          nas-replication@${src.addr} zfs list zroot/incus >/dev/null 2>&1; then
        datasets="$datasets incus"
      fi

      failed=0
      for dataset in $datasets; do
        # Replicate independent siblings after a failure, then fail the unit so
        # the notification still reports the incomplete run.
        if ! syncoid ${mkSyncoidCommonArgs} \
          --no-privilege-elevation \
          --delete-target-snapshots \
          --recvoptions=${unmountedReceiveOptions} \
          --sshkey=${src.key} \
          --sshport=22 \
          --sshoption=BatchMode=yes \
          --sshoption=ConnectTimeout=10 \
          --sshoption=ServerAliveInterval=30 \
          --sshoption=ServerAliveCountMax=3 \
          nas-replication@${src.addr}:zroot/"$dataset" tank/backups/${host}/"$dataset"; then
          echo "ERROR: ${host} replication failed for zroot/$dataset" >&2
          failed=1
        fi
      done

      exit "$failed"
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  mkPullTimer = src: {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = src.onCalendar;
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
  hetznerReplicationKey = "/etc/ssh/nas-replication-hetzner-ed25519";
  hetznerMatrixReplicationKey = "/etc/ssh/nas-replication-hetzner-matrix-ed25519";

  hetznerSaasKey = "/etc/ssh/nas-replication-hetzner-saas-ed25519";

  # hetzner-saas via its tailnet IP; the from= pin in root's
  # authorized_keys there is the NAS's stable tailnet IP (100.64.0.1).
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
      label = "nuc outbound ssd-mirror key";
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
  ]
  ++ pkgs.lib.mapAttrsToList (host: src: {
    label = "${host} outbound pull key";
    path = src.key;
  }) pullSources;

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
  ]
  # A replicated autosnap_* check detects a dead sanoid on a pull source:
  # the pull job's own sync snapshots keep the mirror freshness checks
  # green even if the source stops snapshotting. Hourly snaps plus a daily
  # pull put the newest replicated autosnap at ~26h worst case.
  ++ pkgs.lib.mapAttrsToList (host: src: {
    label = "${host} replicated autosnaps";
    dataset = "tank/backups/${host}/home";
    maxAgeHours = 30;
  }) pullSources;

  # The pc restic backup is file-based (hourly sftp push into tank/backups/pc),
  # so no dataset snapshot check can see it. Restic writes one file per
  # completed snapshot into the repo's snapshots/ directory; the newest file
  # mtime is the last successful backup. pc backs up hourly; 26h absorbs
  # downtime.
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
      deferDuringTankScan = true;
    }
    {
      # Check the child separately; a fresh sibling can mask its stale state.
      label = "local ssd docker container mirror";
      dataset = "tank/backups/ssd/.ix-virt/containers/docker";
      maxAgeHours = 36;
      deferDuringTankScan = true;
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
    {
      label = "hetzner-saas var";
      dataset = "tank/backups/hetzner-saas/var";
      maxAgeHours = 48;
    }
  ]
  # Pull-source mirrors, watched per dataset like hetzner-matrix so one
  # fresh dataset cannot mask a stale sibling. incus mirrors are
  # conditional datasets and deliberately unwatched.
  ++ pkgs.lib.concatLists (
    pkgs.lib.mapAttrsToList (
      host: src:
      map
        (d: {
          label = "${host} ${d} mirror";
          dataset = "tank/backups/${host}/${d}";
          maxAgeHours = 48;
        })
        [
          "home"
          "var"
          "root"
        ]
    ) pullSources
  );

  # Keep tank/backups/ssd mounted as a filesystem: the B2 rclone job reads
  # from this replicated mirror on purpose, instead of racing the live Docker
  # mounts while they are changing. Do not switch this mirror root to
  # mountpoint=none without moving the B2 design at the same time.

  watchdogChecks = pkgs.lib.concatMapStringsSep "\n" (entry: ''
    check_dataset ${pkgs.lib.escapeShellArg entry.label} ${pkgs.lib.escapeShellArg entry.dataset} ${toString entry.maxAgeHours} ${
      if entry.deferDuringTankScan or false then "1" else "0"
    }
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

    tank_scan_active() {
      zpool status tank 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Eq 'scan: (scrub|resilver) in progress'
    }

    check_dataset() {
      label="$1"
      dataset="$2"
      max_age_hours="$3"
      defer_during_tank_scan="''${4:-0}"

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
        if [ "$defer_during_tank_scan" = 1 ] && tank_scan_active; then
          echo "DEFERRED $label freshness alert: $dataset is ''${age_hours}h old while tank is scrubbing or resilvering"
          return
        fi

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

  # No inbound root SSH: since the LAN hosts moved from push (root@nas) to
  # pull, nothing legitimate logs in to this machine as root anymore, so
  # the former "Match User root Address 192.168.1.0/24" carve-out is gone
  # and the shared default root-login denial applies unconditionally.

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

      tank_health="$(zpool list -H -o health tank)"
      if [ "$tank_health" != ONLINE ]; then
        echo "DEFERRED local SSD replication: tank health is $tank_health"
        exit 0
      fi
      if zpool status tank | grep -Eq 'scan: (scrub|resilver) in progress'; then
        echo "DEFERRED local SSD replication: tank is scrubbing or resilvering"
        exit 0
      fi

      # Both SSD mirrors create and prune snapshots on the same source tree.
      exec 9>/run/lock/nas-ssd-replication.lock
      flock 9

      syncoid ${mkSyncoidSsdArgs} ssd tank/backups/ssd

      # syncoid gives newly received .ix-virt children canmount=on and a real
      # mountpoint under the mirror root, but tank/backups/ssd is readonly=on,
      # so `zfs mount -a` cannot create their mountpoint directories. That
      # fails zfs-mount.service, which fails the whole nixos-rebuild switch and
      # blocks comin deploys. Cannot fix this with --recvoptions mountpoint=none
      # because docker/* must stay mounted for the B2 job, so normalize only the
      # Incus subtree. `zfs set` has no recursive flag.
      if zfs list tank/backups/ssd/.ix-virt >/dev/null 2>&1; then
        zfs list -H -o name -r tank/backups/ssd/.ix-virt | while read -r dataset; do
          zfs set canmount=noauto "$dataset"
        done
      fi
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

      # Serialize with nas-replicate-ssd-local; see the matching comment there.
      exec 9>/run/lock/nas-ssd-replication.lock
      flock 9

      # Nothing on the nuc prunes this mirror's replicated autosnap_*
      # snapshots (nuc's sanoid deliberately excludes zroot/backups), so
      # trim it to the source's retention here — without this the mirror
      # accumulates every ssd snapshot forever.
      syncoid ${mkSyncoidSsdArgs} \
        --delete-target-snapshots \
        --recvoptions=${unmountedReceiveOptions} \
        --sshkey=${nucReplicationKey} \
        --sshport=22 \
        --sshoption=BatchMode=yes \
        --sshoption=ConnectTimeout=10 \
        --sshoption=ServerAliveInterval=30 \
        --sshoption=ServerAliveCountMax=3 \
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
      # push jobs do; this also clears foreign-named snapshots (legacy
      # zfs-auto-snap_*), which no prune policy matches.
      # Pull over the tailnet (hetzner = 100.64.0.32) so the from= pin in
      # its authorized_keys is the NAS's stable tailnet IP instead of the
      # dynamic home WAN address, matching the other cloud pulls.
      syncoid ${mkSyncoidCommonArgs} \
        --delete-target-snapshots \
        --sshkey=${hetznerReplicationKey} \
        --sshport=22 \
        --sshoption=BatchMode=yes \
        --sshoption=ConnectTimeout=10 \
        --sshoption=ServerAliveInterval=30 \
        --sshoption=ServerAliveCountMax=3 \
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
      # retention.
      for dataset in tuwunel var; do
        syncoid ${mkSyncoidCommonArgs} \
          --delete-target-snapshots \
          --sshkey=${hetznerMatrixReplicationKey} \
          --sshport=22 \
          --sshoption=BatchMode=yes \
          --sshoption=ConnectTimeout=10 \
          --sshoption=ServerAliveInterval=30 \
          --sshoption=ServerAliveCountMax=3 \
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

  systemd.services.nas-replicate-hetzner-saas = {
    description = "Replicate hetzner-saas zroot/var over SSH";
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

      # zroot/var carries everything that matters on this host: the k3s
      # server state (sqlite DB, join token, TLS, manifests) under
      # /var/lib/rancher plus the mindroom-saas hcloud token. /etc/rancher
      # is regenerated by k3s on start; the rest of zroot is rebuildable
      # from this repo. Customer PVC data lives on Hetzner Cloud Volumes
      # via the hcloud CSI and is NOT inside this dataset.
      syncoid ${mkSyncoidCommonArgs} \
        --delete-target-snapshots \
        --sshkey=${hetznerSaasKey} \
        --sshport=22 \
        --sshoption=BatchMode=yes \
        --sshoption=ConnectTimeout=10 \
        --sshoption=ServerAliveInterval=30 \
        --sshoption=ServerAliveCountMax=3 \
        root@${hetznerSaasHost}:zroot/var tank/backups/hetzner-saas/var
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-replicate-hetzner-saas = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 01:05:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.nas-replicate-pc = mkPullService "pc" pullSources.pc;
  systemd.services.nas-replicate-nuc = mkPullService "nuc" pullSources.nuc;
  systemd.services.nas-replicate-hp = mkPullService "hp" pullSources.hp;
  systemd.services.nas-replicate-pi4 = mkPullService "pi4" pullSources.pi4;

  systemd.timers.nas-replicate-pc = mkPullTimer pullSources.pc;
  systemd.timers.nas-replicate-nuc = mkPullTimer pullSources.nuc;
  systemd.timers.nas-replicate-hp = mkPullTimer pullSources.hp;
  systemd.timers.nas-replicate-pi4 = mkPullTimer pullSources.pi4;

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
