# Raspberry Pi 4 hardware configuration
#
# Most hardware config is handled by nixos-raspberrypi.nixosModules.raspberry-pi-4.base
# This file only contains ZFS-specific and additional customizations.
{ config, lib, pkgs, ... }:

{
  # ZFS support (not provided by nixos-raspberrypi)
  boot.supportedFilesystems = [ "zfs" ];

  # Ensure WiFi driver loads on boot (critical for headless)
  boot.kernelModules = [ "brcmfmac" ];

  # Swap - recommended for RPi4's limited RAM (2-8GB)
  swapDevices = [
    { device = "/swapfile"; size = 2048; }
  ];

  # Power management optimizations for RPi4
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # Disable firmware updates (RPi firmware is handled by nixos-raspberrypi)
  services.fwupd.enable = lib.mkForce false;
}
