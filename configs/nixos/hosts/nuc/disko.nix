{ ... }:
(import ../../common/disko-zfs.nix) {
  device = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2344E884093A";
  espLabel = "EFI-NUC";
}
