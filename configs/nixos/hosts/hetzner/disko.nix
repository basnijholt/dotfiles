# Hetzner Cloud disk configuration with ZFS (ARM)
#
# Uses common ZFS layout. Hetzner exposes disk as /dev/sda.
{ ... }:
(import ../../common/disko-zfs.nix) {
  device = "/dev/sda";
  espLabel = "ESP-HETZNER";
}
