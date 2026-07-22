{ lib, pkgs, ... }:

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
    interval = "Sun *-*-* 00:00:00";
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
    # mirrors accumulate every source snapshot forever. Since the 2026-07
    # fleet migration to sanoid every source delivers autosnap_* names, so
    # this policy covers all mirrors; the push/pull jobs additionally trim
    # targets to the source's snapshot set with --delete-target-snapshots.
    # Retention here is a superset of every source policy (nas-default
    # above, zfs-default elsewhere), so a target never keeps less history
    # than its source intends. Sanoid only prunes snapshots it named
    # itself; syncoid sync snaps, legacy zfs-auto-snap_* snapshots (until
    # their one-time manual cleanup), and TrueNAS-era snapshots are
    # untouched.
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
  systemd.services.sanoid.unitConfig.OnFailure = [ "nas-health-alert@%n.service" ];

  environment.systemPackages = with pkgs; [
    hdparm
    lzop
    mbuffer
    nvme-cli
    smartmontools
    unlockEncryptedDatasets
    zfs
  ];
}
