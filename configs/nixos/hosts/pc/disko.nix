{ ... }:
{
  imports = [
    ((import ../../common/disko-zfs.nix) {
      # The NixOS root disk (Samsung 990 EVO Plus 4TB, /dev/nvme1n1 today).
      # by-id so the destructive disko run can never pick the wrong disk.
      device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0Y206553P";
      espLabel = "EFI-PC";
      # pc actively swaps under AI workloads; swapfiles do not work on ZFS,
      # so this becomes a dedicated partition (was a 96G btrfs swapfile).
      swapSize = "96G";
    })
  ];

  # Only used to size the sparse virtual disk for `nixos-anywhere --vm-test`
  # and disko VM tests (the 2G default cannot fit the swap partition).
  # Irrelevant on real hardware.
  disko.devices.disk.main.imageSize = "120G";
}
