{ ... }:
(import ../../common/disko-zfs.nix) {
  device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_500GB_S466NX0MC21160Z";
  espLabel = "EFI-NAS";
}
