# Hetzner Cloud x86_64 disk configuration.
#
# Hetzner Cloud x86_64 instances boot through legacy BIOS, so GRUB needs a
# BIOS boot partition on GPT.
{ ... }:

{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          bios = {
            size = "1M";
            type = "EF02";
          };
          root = {
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
}
