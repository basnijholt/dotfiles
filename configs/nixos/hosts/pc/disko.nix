{ lib, ... }:

let
  # Shared mount options that balance performance and drive health on NVMe.
  mountOpts = [
    "compress=zstd"
    "noatime"
    "discard=async"
    "space_cache=v2"
  ];
in
{
  disko.devices = {
    disk = {
      nvme1 = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              label = "EFI-NVME1";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot2";
                mountOptions = [ "umask=0077" ];
              };
            };

            root = {
              label = "ROOT-NVME1";
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-L" "NVME1-BTRFS" ];
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
  };
}
