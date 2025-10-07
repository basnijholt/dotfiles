{ ... }:

{
  disko.devices = {
    disk.nvme = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2344E884093A";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          rpool = {
            type = "BF01"; # existing ZFS member
            content = {
              type = "zpool";
              name = "rpool";
              mode = "disk";
              rootFsOptions = {
                mountpoint = "none";
              };

              datasets = {
                "ROOT" = {
                  type = "zfs_fs";
                  options = {
                    mountpoint = "none";
                    canmount = "off";
                  };
                };

                "ROOT/nixos" = {
                  type = "zfs_fs";
                  options = {
                    mountpoint = "none";
                    canmount = "off";
                  };
                };

                "ROOT/nixos/system" = {
                  type = "zfs_fs";
                  mountpoint = "/";
                  options = {
                    mountpoint = "legacy";
                    canmount = "noauto";
                  };
                };

                "nix" = {
                  type = "zfs_fs";
                  mountpoint = "/nix";
                  options = {
                    mountpoint = "legacy";
                    canmount = "noauto";
                  };
                };

                "var/log" = {
                  type = "zfs_fs";
                  mountpoint = "/var/log";
                  options = {
                    mountpoint = "legacy";
                    canmount = "noauto";
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

