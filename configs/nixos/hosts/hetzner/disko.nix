# Hetzner Cloud disk configuration
#
# Uses GPT with:
# - 1MB BIOS boot partition (for legacy GRUB)
# - 512MB EFI partition (for UEFI, future-proofing)
# - Rest as ext4 root (simple, reliable for VPS)
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
            # BIOS boot partition for legacy GRUB (required for Hetzner x86_64)
            boot = {
              size = "1M";
              type = "EF02"; # BIOS boot
              priority = 1;
            };
            # EFI System Partition
            ESP = {
              label = "EFI-HETZNER";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            # Root partition
            root = {
              label = "ROOT-HETZNER";
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
