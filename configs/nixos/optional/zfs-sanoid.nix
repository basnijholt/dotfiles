# ZFS automated local snapshots via Sanoid.
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
      "zroot/root" = {
        useTemplate = [ "zfs-default" ];
        recursive = "zfs";
      };
      "zroot/var" = {
        useTemplate = [ "zfs-default" ];
        recursive = "zfs";
      };
      "zroot/home" = {
        useTemplate = [ "zfs-default" ];
        recursive = "zfs";
      };
    };
  };

  environment.systemPackages = [ pkgs.sanoid ];
}
