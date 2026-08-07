{ ... }:

{
  # nixos-anywhere owns only the boot disk. The separate GCE work disk must
  # never appear here: agent-work-disk initializes it interactively as LUKS2.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/google-agent-boot";
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
            extraArgs = [ "-L" "nixos" ];
            mountpoint = "/";
          };
        };
      };
    };
  };
}
