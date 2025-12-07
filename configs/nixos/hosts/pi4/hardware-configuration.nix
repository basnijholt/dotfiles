# Raspberry Pi 4 hardware configuration (UEFI boot)
#
# Uses pftf/RPi4 UEFI firmware for standard NixOS boot.
# No nixos-raspberrypi flake needed - vanilla aarch64 NixOS.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # --- Boot Configuration (UEFI with systemd-boot) ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = true;
  boot.zfs.devNodes = "/dev/disk/by-id";

  # Kernel modules for Pi 4 with UEFI
  # Based on: https://www.eisfunke.com/posts/2023/nixos-on-raspberry-pi-4.html
  boot.initrd.availableKernelModules = [
    "usbhid"        # USB HID devices
    "usb_storage"   # USB mass storage
    "vc4"           # VideoCore 4 GPU
    "pcie_brcmstb"  # Broadcom PCIe controller
    "reset-raspberrypi"  # Pi reset controller
    "xhci_pci"      # USB 3.0
    "uas"           # USB Attached SCSI
  ];

  # ZFS must be in initrd to mount root
  boot.initrd.kernelModules = [ "zfs" ];

  # WiFi driver
  boot.kernelModules = [ "brcmfmac" ];

  # --- Filesystem Configuration ---
  # Add zfsutil option for proper ZFS property handling
  fileSystems."/" = {
    device = "zroot/root";
    fsType = "zfs";
    options = [ "zfsutil" "X-mount.mkdir" ];
  };

  fileSystems."/nix" = {
    device = "zroot/nix";
    fsType = "zfs";
    options = [ "zfsutil" "X-mount.mkdir" ];
  };

  fileSystems."/var" = {
    device = "zroot/var";
    fsType = "zfs";
    options = [ "zfsutil" "X-mount.mkdir" ];
  };

  fileSystems."/home" = {
    device = "zroot/home";
    fsType = "zfs";
    options = [ "zfsutil" "X-mount.mkdir" ];
  };

  # /boot is defined by disko.nix (ESP partition)

  # --- Hardware ---
  # WiFi firmware
  hardware.firmware = [ pkgs.raspberrypiWirelessFirmware ];
  hardware.enableRedistributableFirmware = true;

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # Disable fwupd (not useful for Pi)
  services.fwupd.enable = lib.mkForce false;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
