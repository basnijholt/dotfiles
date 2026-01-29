# Paul's Wyse 5070 disk configuration with ZFS
#
# Uses common ZFS disko config. Wyse 5070 has 32GB eMMC
# exposed as /dev/mmcblk0.
{ lib, ... }:
let
  common = (import ../../common/disko-zfs.nix) {
    device = "/dev/mmcblk0";
    espLabel = "ESP-PAULWYSE";
  };
in
{
  disko.devices = common.disko.devices;
}
