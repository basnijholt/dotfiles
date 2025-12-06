# Raspberry Pi 4 hardware configuration
#
# Installation notes:
#   1. Build SD card image: nix build .#nixosConfigurations.pi4.config.system.build.sdImage
#   2. Flash to SD card: dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress
#   3. Boot the Pi and SSH in (user: basnijholt)
#   4. After first boot, run: nixos-generate-config --show-hardware-config
  # Update this file with actual UUIDs from generated config if needed
{ lib, modulesPath, ... }:

{
  imports = [ ];

  # Raspberry Pi 4 specific
  nixpkgs.hostPlatform = "aarch64-linux";

  # Boot configuration - RPi uses its own bootloader chain
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Kernel modules for RPi4
  boot.initrd.availableKernelModules = [ "usbhid" "usb_storage" "vc4" "pcie_brcmstb" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.supportedFilesystems = [ "zfs" ];

  # Required firmware for WiFi, Bluetooth, GPU
  hardware.enableRedistributableFirmware = true;

  # SD card / USB boot filesystem
  # The sd-image module handles this automatically for initial boot
  # After installation, you may want to set explicit UUIDs:
  # fileSystems."/" = {
  #   device = "/dev/disk/by-label/NIXOS_SD";
  #   fsType = "ext4";
  # };

  # Swap - recommended for RPi4's limited RAM (2-8GB)
  swapDevices = [
    { device = "/swapfile"; size = 2048; }
  ];

  # Power management optimizations for RPi4
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # Disable firmware updates (RPi firmware is handled differently)
  services.fwupd.enable = lib.mkForce false;
}
