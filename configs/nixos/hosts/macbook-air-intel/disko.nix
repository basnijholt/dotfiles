{ ... }:
(import ../../common/disko-zfs.nix) {
  device = "/dev/nvme0n1";
  espLabel = "ESP";
}