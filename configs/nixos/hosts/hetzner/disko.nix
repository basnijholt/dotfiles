# Hetzner Cloud disk configuration with ZFS (ARM)
#
# Uses common ZFS disko config with Hetzner-specific label.
# Hetzner exposes the disk as /dev/sda.
{ lib, ... }:
let
  common = (import ../../common/disko-zfs.nix) {
    device = "/dev/sda";
    espLabel = "ESP-HETZNER";
  };
in
{
  disko.devices = lib.recursiveUpdate common.disko.devices {
    zpool.zroot.datasets.websites = {
      type = "zfs_fs";
      mountpoint = "/home/basnijholt/websites";
      options = {
        mountpoint = "legacy";
        compression = "lz4";
        atime = "off";
        "com.sun:auto-snapshot" = "true";
      };
    };
  };
}
