# ZFS automated local snapshots via Sanoid.
#
# Fleet standard since 2026-07: sanoid everywhere, one `autosnap_*` naming
# scheme, so target-side retention policies (like the NAS's nas-backup-prune)
# can reason about every replicated snapshot. This replaced
# services.zfs.autoSnapshot (`zfs-auto-snap_*` naming), which sanoid can
# never prune — that split is what let the hetzner mirror accumulate 700+
# snapshots unnoticed.
#
# Covers zroot recursively; zroot/nix is rebuildable and excluded. Hosts
# with datasets sanoid must not touch add their own exclusions (hp:
# zroot/incus, nuc: zroot/backups).
#
# Legacy zfs-auto-snap_* snapshots stopped being created at the migration
# and are destroyed manually on each source once; targets self-clean because
# every replication job runs --delete-target-snapshots.
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
