# Raspberry Pi 4 hardware configuration
#
# Most hardware config is handled by nixos-raspberrypi.nixosModules.raspberry-pi-4.base
# This file only contains ZFS-specific and additional customizations.
{ config, lib, pkgs, ... }:

{
  # ZFS support (not provided by nixos-raspberrypi)
  boot.supportedFilesystems = [ "zfs" ];

  # CRITICAL: Force ZFS import even if hostId doesn't match
  # The pool is created on the build PC (different hostId) but boots on Pi
  boot.zfs.forceImportRoot = true;

  # USB drivers needed in initrd to find root filesystem on USB SSD
  boot.initrd.availableKernelModules = [
    "xhci_pci"        # USB 3.0 controller (required for USB boot)
    "usb_storage"     # USB mass storage
    "usbhid"          # USB HID (keyboard)
    "uas"             # USB Attached SCSI (better SSD performance)
  ];

  # Wait for USB devices to enumerate before ZFS import
  # USB SSDs can take a few seconds to appear on RPi
  boot.initrd.postDeviceCommands = lib.mkBefore ''
    echo "Waiting for USB devices to settle..."
    sleep 3
  '';

  # Ensure WiFi driver loads on boot (critical for headless)
  boot.kernelModules = [ "brcmfmac" ];

  # Explicit WiFi firmware (safety net for headless)
  hardware.firmware = [ pkgs.raspberrypiWirelessFirmware ];

  # Note: Swap via zvol is optional - ZFS doesn't support swapfiles
  # Uncomment below if swap is needed (creates 2GB zvol):
  # swapDevices = [{ device = "/dev/zvol/zroot/swap"; }];
  # To create: zfs create -V 2G -b $(getconf PAGESIZE) zroot/swap

  # Power management optimizations for RPi4
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # Disable firmware updates (RPi firmware is handled by nixos-raspberrypi)
  services.fwupd.enable = lib.mkForce false;
}
