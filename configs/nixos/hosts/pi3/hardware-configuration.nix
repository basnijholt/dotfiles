# Raspberry Pi 3 hardware configuration (SD card)
#
# Hardware support is provided by nixos-raspberrypi.nixosModules.raspberry-pi-3.base
# This just defines the filesystem layout for the SD card.
{ lib, ... }:

{
  # Root filesystem on SD card (ext4)
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  # Boot firmware partition
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "noatime" "noauto" "x-systemd.automount" ];
  };

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
