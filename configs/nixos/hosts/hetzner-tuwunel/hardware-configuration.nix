# Hetzner Cloud VPS hardware configuration (ARM)
#
# Ampere Altra ARM64 for Hetzner Cloud CAX series.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ "virtio_gpu" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ "console=tty" ];

  boot.supportedFilesystems = [ "zfs" ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
