# Raspberry Pi 3 hardware configuration (UEFI boot)
#
# Uses pftf/RPi3 UEFI firmware for standard NixOS boot.
# Debug host with HDMI/ethernet for troubleshooting boot issues.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/pi-uefi.nix
  ];

  # --- UEFI Firmware (declarative) ---
  hardware.raspberry-pi.uefi.enable = true;
  hardware.raspberry-pi.uefi.model = "rpi3";

  # --- Boot Configuration (UEFI with systemd-boot) ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = true;
  boot.zfs.devNodes = "/dev/disk/by-id";

  # Kernel modules for Pi 3 with UEFI
  boot.initrd.availableKernelModules = [
    "usbhid"        # USB HID devices
    "usb_storage"   # USB mass storage
    "vc4"           # VideoCore 4 GPU
    "xhci_pci"      # USB 3.0 (via USB hub)
    "uas"           # USB Attached SCSI
  ];

  # ZFS must be in initrd to mount root
  boot.initrd.kernelModules = [ "zfs" ];

  # USB storage can be slow to enumerate on Pi; wait for devices
  boot.initrd.postDeviceCommands = lib.mkBefore ''
    echo "Waiting for USB devices to settle..."
    sleep 8
  '';

  # WiFi driver (Pi 3 uses same brcmfmac)
  boot.kernelModules = [ "brcmfmac" ];
  boot.kernelParams = [
    "rootdelay=10"          # USB SSD enumeration can be slow
    "console=ttyAMA0,115200"
    "console=tty1"
  ];

  # --- Filesystem Configuration ---
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
