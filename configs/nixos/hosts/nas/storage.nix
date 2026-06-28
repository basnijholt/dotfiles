{ lib, pkgs, ... }:

let
  unlockEncryptedDatasets = pkgs.writeShellScriptBin "zfs-unlock-encrypted-datasets" ''
    set -euo pipefail

    encrypted_roots="$(
      ${pkgs.zfs}/bin/zfs list -H -o name,encryptionroot,keystatus -t filesystem,volume |
        ${pkgs.gawk}/bin/awk '$2 == $1 && $3 == "unavailable" { print $1 }'
    )"

    if [ -z "$encrypted_roots" ]; then
      echo "No unavailable encrypted ZFS roots found"
      exit 0
    fi

    echo "$encrypted_roots" | while IFS= read -r dataset; do
      status="$(${pkgs.zfs}/bin/zfs get -H -o value keystatus "$dataset")"
      if [ "$status" = "unavailable" ]; then
        # One failure (e.g. jailmaker's stale file:///tmp/zfs_pass keylocation,
        # or a wrong passphrase) must not abort unlocking the remaining datasets.
        ${pkgs.zfs}/bin/zfs load-key "$dataset" || echo "WARNING: could not load key for $dataset; skipping" >&2
      fi
    done

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
    datasets = {
      tank = {
        useTemplate = [ "nas-default" ];
        recursive = true;
      };
      ssd = {
        useTemplate = [ "nas-default" ];
        recursive = "zfs";
      };
    };
  };

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
