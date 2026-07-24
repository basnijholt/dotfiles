{ pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/desktop.nix
    ../../optional/audio.nix
    ../../optional/virtualization.nix
    ../../optional/gui-packages.nix
    ../../optional/large-packages.nix
    ../../optional/power.nix
    ../../optional/zfs-replication-source.nix
    ../../optional/nfs-docker.nix
    ../../optional/ups-client.nix
    ../../optional/wake-on-lan.nix
    (import ../../optional/coredns.nix { listenIP = "192.168.1.2"; })

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./system-packages.nix
    ./kodi.nix
  ];

  # Required for ZFS
  networking.hostId = "8a5b2c1f";
  boot.zfs.forceImportRoot = false;

  # zroot/backups is the received mirror of the NAS ssd pool. Sanoid must
  # neither snapshot it (pollutes the replica) nor prune it (its autosnap_*
  # history belongs to the source's retention, enforced by the NAS push
  # job's --delete-target-snapshots).
  services.sanoid.datasets."zroot/backups" = {
    autosnap = false;
    autoprune = false;
    recursive = true;
  };

  local.wakeOnLan.interface = "eno1";
  local.zfsReplicationSource.nasPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBVT4xCHl6p6NAJpFjhW+tw29fj1ZrqOUIWRuuwPmZ3 nas-replication-nuc-pull";

  systemd.services.nuc-backup-zfs-policy = {
    description = "Keep replicated NAS backup datasets from auto-mounting";
    before = [ "zfs-mount.service" ];
    wantedBy = [ "zfs-mount.service" ];
    path = with pkgs; [
      coreutils
      zfs
    ];
    script = ''
      set -euo pipefail

      if ! zfs list zroot/backups >/dev/null 2>&1; then
        exit 0
      fi

      zfs set mountpoint=none readonly=on zroot/backups
      zfs list -H -r -o name zroot/backups | while read -r dataset; do
        zfs set canmount=noauto "$dataset"
      done
    '';
    serviceConfig.Type = "oneshot";
  };
}
