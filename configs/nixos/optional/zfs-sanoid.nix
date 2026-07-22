# ZFS automated local snapshots via Sanoid.
#
# Fleet standard: sanoid everywhere with one `autosnap_*` naming scheme, so
# target-side retention policies (like the NAS's nas-backup-prune) can
# reason about every replicated snapshot. Sanoid never prunes names it did
# not create, so any second snapshot tool in the fleet would make its
# snapshots invisible to every prune policy and accumulate on the mirrors.
#
# Covers zroot recursively; zroot/nix is rebuildable and excluded. Hosts
# with datasets sanoid must not touch add their own exclusions (hp:
# zroot/incus, nuc: zroot/backups).
{ pkgs, ... }:

{
  services.sanoid = {
    enable = true;
    interval = "*:0/10";
    templates.zfs-default = {
      autosnap = true;
      autoprune = true;
      frequently = 6;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 12;
    };
    datasets = {
      zroot = {
        useTemplate = [ "zfs-default" ];
        recursive = true;
      };
      # The nix store is rebuildable; snapshotting it only burns space.
      "zroot/nix" = {
        autosnap = false;
        autoprune = false;
        recursive = true;
      };
    };
  };

  environment.systemPackages = [ pkgs.sanoid ];
}
