{
  config,
  lib,
  pkgs,
  ...
}:

let
  unlockEncryptedDatasets = pkgs.writeShellScriptBin "zfs-unlock-encrypted-datasets" ''
    set -euo pipefail

    encrypted_roots_and_keylocations="$(
      ${pkgs.zfs}/bin/zfs list -H -o name,encryptionroot,keystatus,keylocation -t filesystem,volume |
        ${pkgs.gawk}/bin/awk '$2 == $1 && $3 == "unavailable" { print $1 "\t" $4 }'
    )"

    if [ -z "$encrypted_roots_and_keylocations" ]; then
      echo "No unavailable encrypted ZFS roots found"
      exit 0
    fi

    while IFS="$(printf '\t')" read -r dataset keylocation; do
      if [ "$keylocation" != "prompt" ]; then
        echo "Skipping $dataset: keylocation=$keylocation"
        continue
      fi

      status="$(${pkgs.zfs}/bin/zfs get -H -o value keystatus "$dataset")"
      if [ "$status" = "unavailable" ]; then
        # Read the passphrase from the terminal instead of the dataset list.
        # One wrong passphrase must not abort unlocking the remaining datasets.
        ${pkgs.zfs}/bin/zfs load-key "$dataset" </dev/tty || echo "WARNING: could not load key for $dataset; skipping" >&2
      fi
    done <<< "$encrypted_roots_and_keylocations"

    ${pkgs.zfs}/bin/zfs mount -a >/dev/null 2>&1 || true
  '';
in
{
  boot.zfs = {
    devNodes = "/dev/disk/by-id";
    extraPools = [
      "ssd"
      "tank"
    ];
    forceImportRoot = lib.mkForce false;
    requestEncryptionCredentials = lib.mkForce false;
  };

  # 2026-07-05 outage: the Samsung 990 EVO Plus mirror leg on the ssd pool
  # produced PCIe AER replay-timeout storms under scrub/replication load, which
  # stalled ZFS transaction commits. Disable PCIe ASPM and NVMe APST so the
  # drive/link stay out of the low-power states that trigger this failure mode.
  boot.kernelParams = [
    "pcie_aspm=off"
    "nvme_core.default_ps_max_latency_us=0"
  ];

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # Cap the ZFS ARC at 16 GiB (default is ~50% of RAM, ~31 GiB here). This host
  # has 64 GiB, no ECC, and a history of OOM under heavy container load, so we
  # trade cache for predictable headroom for the Incus workloads.
  boot.extraModprobeConfig = ''
    options zfs zfs_arc_max=17179869184
  '';

  services.zfs.autoScrub = {
    enable = true;
    pools = [
      "ssd"
      "tank"
    ];
    # Monthly, not weekly: a tank scrub takes ~2d7h, so a weekly schedule kept
    # the array under full seek load roughly a third of the time and pushed
    # drive temps from ~51C to 60C, the Ultrastar spec ceiling.
    interval = "*-*-01 03:00:00";
  };

  services.sanoid = {
    templates.nas-default = {
      autosnap = true;
      autoprune = true;
      frequent_period = 10;
      frequently = 12;
      hourly = 48;
      daily = 31;
      weekly = 52;
      monthly = 1;
    };
    # Replication targets under tank/backups: never snapshot here, but prune
    # the autosnap_ snapshots that replication delivers — otherwise the
    # mirrors accumulate every source snapshot forever. Every source
    # delivers sanoid-named autosnap_* snapshots, so this policy covers all
    # mirrors; the push/pull jobs additionally trim targets to the source's
    # snapshot set with --delete-target-snapshots. Retention here is a
    # superset of every source policy (nas-default above, zfs-default
    # elsewhere), so a target never keeps less history than its source
    # intends. Sanoid only prunes snapshots it named itself; syncoid sync
    # snaps and foreign-named snapshots (legacy zfs-auto-snap_*,
    # TrueNAS-era) are untouched.
    templates.nas-backup-prune = {
      autosnap = false;
      autoprune = true;
      frequently = 12;
      hourly = 48;
      daily = 31;
      weekly = 52;
      monthly = 12;
    };
    datasets = {
      tank = {
        useTemplate = [ "nas-default" ];
        recursive = true;
      };
      # Irreplaceable low-churn datasets: extend monthly retention so local
      # restore points reach ~2 years back (the template's weekly=52 caps
      # history at ~1 year). Near-free for data that barely changes.
      "tank/photos" = {
        useTemplate = [ "nas-default" ];
        recursive = true;
        monthly = 24;
      };
      "tank/syncthing" = {
        useTemplate = [ "nas-default" ];
        recursive = true;
        monthly = 24;
      };
      "tank/backups" = {
        useTemplate = [ "nas-backup-prune" ];
        recursive = true;
      };
      # The pc restic repo is the one backup its source can destroy: pc
      # pushes over sftp as the restic user, which owns every file in the
      # repo, so a compromised pc could delete or encrypt it remotely.
      # Local snapshots make the repo rollbackable; pc cannot touch ZFS
      # snapshots. Retention is modest because restic prune churn makes
      # old snapshots pin dead pack files. (The other file-based backup,
      # hetzner-saas, needs none of this: it is pull-only — the source
      # holds no NAS credentials — and keeps 30 dated tarballs anyway.)
      "tank/backups/pc" = {
        autosnap = true;
        autoprune = true;
        frequently = 0;
        hourly = 48;
        daily = 14;
        weekly = 4;
        monthly = 0;
      };
      ssd = {
        useTemplate = [ "nas-default" ];
        recursive = "zfs";
      };
    };
  };

  # Sanoid failures must alert: syncoid's own sync snapshots keep the
  # replication watchdog green even when autosnapshots have stopped, so a
  # silently failing sanoid would otherwise go unnoticed.
  systemd.services.sanoid = {
    unitConfig.OnFailure = [ "nas-health-alert@%n.service" ];
    # The generated default is only 90 seconds. Pool-wide zfs allow checks and
    # snapshotting can take several minutes while a large scrub or resilver is
    # active, which otherwise produces a false failure alert.
    serviceConfig = {
      TimeoutStartSec = "15m";
      # OpenZFS cannot resolve systemd's transient sanoid account for `zfs
      # allow`, so the generated DynamicUser service cannot prune snapshots.
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
      ExecStartPre = lib.mkForce [ ];
      ExecStopPost = lib.mkForce [ ];
      # Syncoid holds source snapshots while sending; skip this cycle instead
      # of racing Sanoid pruning against the replication hold.
      ExecStart = lib.mkForce "${pkgs.util-linux}/bin/flock --nonblock --conflict-exit-code 0 /run/lock/nas-ssd-replication.lock ${config.services.sanoid.package}/bin/sanoid --cron --configdir /etc/sanoid";
    };
  };

  environment.systemPackages = with pkgs; [
    # Read-only surface scans of a failing member: unlike smartctl -t long,
    # which stops at the first uncorrectable sector, ddrescue maps every bad
    # extent in one pass and keeps a resumable mapfile.
    ddrescue
    hdparm
    lzop
    mbuffer
    nvme-cli
    smartmontools
    unlockEncryptedDatasets
    zfs
  ];
}
