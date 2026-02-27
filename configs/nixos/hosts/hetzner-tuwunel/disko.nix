# Hetzner Cloud disk configuration with ZFS (ARM)
#
# ZFS root with a dedicated dataset for tuwunel data.
{ lib, ... }:
let
  common = (import ../../common/disko-zfs.nix) {
    device = "/dev/sda";
    espLabel = "ESP-TUWUNEL";
  };
in
{
  disko.devices = lib.recursiveUpdate common.disko.devices {
    zpool.zroot.datasets.tuwunel = {
      type = "zfs_fs";
      mountpoint = "/var/lib/tuwunel";
      options = {
        mountpoint = "legacy";
        compression = "lz4";
        atime = "off";
        # recordsize=16k is better for RocksDB workloads
        recordsize = "16K";
      };
    };
  };
}
