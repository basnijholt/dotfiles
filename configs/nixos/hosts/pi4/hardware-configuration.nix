# Raspberry Pi 4 hardware configuration
#
# Hardware handled by nixos-raspberrypi.nixosModules.raspberry-pi-4.base
# This file adds ZFS-specific configuration and critical boot fixes.
{ config, lib, pkgs, ... }:

{
  # ZFS support (not provided by nixos-raspberrypi)
  boot.supportedFilesystems = [ "zfs" ];
  boot.initrd.supportedFilesystems = [ "zfs" ];  # Critical for ZFS root!

  # CRITICAL: Force ZFS import even if hostId doesn't match
  boot.zfs.forceImportRoot = true;
  boot.zfs.devNodes = "/dev/disk/by-partuuid";  # More reliable for USB on Pi

  # USB drivers needed in initrd to find root filesystem on USB SSD
  boot.initrd.availableKernelModules = [
    "xhci_pci"        # USB 3.0 controller
    "usb_storage"     # USB mass storage
    "usbhid"          # USB HID
    "uas"             # USB Attached SCSI
  ];

  # Wait for USB devices to enumerate before ZFS import
  boot.initrd.postDeviceCommands = lib.mkBefore ''
    echo "Waiting for USB devices to settle..."
    sleep 3
  '';

  # Kernel params for ZFS boot
  boot.kernelParams = [
    "zfs_force=1"           # Force ZFS import regardless of hostid
  ];

  # --- Filesystem Configuration ---
  # NOTE: Do NOT use zfsutil - it causes "cannot be mounted" errors with legacy mountpoints
  fileSystems."/" = {
    device = "zroot/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "zroot/nix";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "zroot/var";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zroot/home";
    fsType = "zfs";
  };

  # /boot is defined by disko.nix (ESP partition)
  # Override firmwarePath to match bootPath since we have a single boot partition
  # (nixos-raspberrypi defaults to separate /boot and /boot/firmware)
  boot.loader.raspberryPi.firmwarePath = "/boot";

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # Disable fwupd (firmware handled by nixos-raspberrypi)
  services.fwupd.enable = lib.mkForce false;
}
