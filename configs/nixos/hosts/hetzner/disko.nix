# Hetzner Cloud disk configuration with ZFS (ARM)
#
# Uses common ZFS disko config with Hetzner-specific label.
# Hetzner exposes the disk as /dev/sda.
(import ../../common/disko-zfs.nix) {
  device = "/dev/sda";
  espLabel = "ESP-HETZNER";
}
