{ lib, ... }:

let
  mountOpts = [
    "compress=zstd"
    "noatime"
    "discard=async"
    "space_cache=v2"
  ];
in
{
  disko.devices = {
    disk.nvme = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2344E884093A";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            label = "EFI-NUC";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          root = {
            label = "ROOT-NUC";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" "-L" "NUC-BTRFS" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = mountOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = mountOpts;
                };
                "@var" = {
                  mountpoint = "/var";
                  mountOptions = mountOpts;
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = mountOpts;
                };
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = mountOpts;
                };
              };
            };
          };
        };
      };
    };
  };
}
