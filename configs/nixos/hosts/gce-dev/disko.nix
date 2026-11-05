# GCE disk layout: standard fleet ESP + zroot from common/disko-zfs.nix.
#
# C4-family machines expose Hyperdisk over NVMe. The device path only matters
# at install time (nixos-anywhere); afterwards the pool imports by name and
# the ESP mounts by partition label.
(import ../../common/disko-zfs.nix) {
  device = "/dev/nvme0n1";
  espLabel = "ESP-GCE";
}
