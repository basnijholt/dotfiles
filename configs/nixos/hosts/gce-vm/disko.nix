{ ... }:

{
  # Arm variant: UEFI only, so an ESP replaces the BIOS boot partition.
  # google-* aliases resolve for both SCSI and NVMe attachments.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/google-agent-boot";
    content = {
      type = "gpt";
      partitions = {
        esp = {
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
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [
              "-L"
              "nixos"
            ];
            mountpoint = "/";
          };
        };
      };
    };
  };
}
