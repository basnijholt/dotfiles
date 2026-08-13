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

let
  sanoidWithCacheFix = pkgs.sanoid.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (pkgs.fetchurl {
        url = "https://github.com/jimsalterjrs/sanoid/commit/393a4672e5695af5a5a8c82faed455e5689e0c69.patch";
        hash = "sha256-H0KmC4od6fkCizAm66aDVcGvv2ImBBu4Wn20FU4XzBE=";
      })
      (pkgs.fetchurl {
        url = "https://github.com/jimsalterjrs/sanoid/commit/2343089a0809740d0dad27c74e54f43153e558fd.patch";
        hash = "sha256-EfHBZePKpdGwkaYCXYltzds6zXBeIH/6MFlmo+dlapY=";
      })
    ];
  });
in

{
  services.sanoid = {
    enable = true;
    package = sanoidWithCacheFix;
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

  environment.systemPackages = [ sanoidWithCacheFix ];
}
