# Hetzner Cloud disk configuration with ZFS
#
# Hetzner x86_64 uses legacy BIOS boot (not UEFI).
# Uses GPT with:
# - 1MB BIOS boot partition (for GRUB core.img)
# - 512MB /boot partition (ext4, since GRUB can't read ZFS on legacy BIOS)
# - Rest as ZFS pool
#
# Hetzner exposes the disk as /dev/sda.
{ ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition for legacy GRUB
            bios = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };
            # Boot partition (ext4 - GRUB can't read ZFS on legacy BIOS)
            boot = {
              label = "BOOT-HETZNER";
              size = "512M";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
              };
            };
            # ZFS partition
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      zroot = {
        type = "zpool";
        mode = ""; # Single disk
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options.mountpoint = "legacy";
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options.mountpoint = "legacy";
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };
        };
      };
    };
  };
}
