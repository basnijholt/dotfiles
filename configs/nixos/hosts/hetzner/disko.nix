# Hetzner Cloud disk configuration
#
# Hetzner x86_64 uses legacy BIOS boot (not UEFI).
# Uses GPT with:
# - 1MB BIOS boot partition (for GRUB core.img)
# - 512MB /boot partition (ext4)
# - Rest as ext4 root
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
              type = "EF02"; # BIOS boot partition
              priority = 1;
            };
            # Boot partition
            boot = {
              label = "BOOT-HETZNER";
              size = "512M";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
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
