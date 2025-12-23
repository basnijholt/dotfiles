# Hetzner Cloud VPS hardware configuration (ARM)
#
# Ampere Altra ARM64 guest configuration for Hetzner Cloud CAX series.
# Uses UEFI boot with ZFS root.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Kernel modules for virtio (Hetzner uses KVM)
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ "virtio_gpu" ]; # Required for ARM console
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ "console=tty" ]; # Required for ARM console output

  boot.supportedFilesystems = [ "zfs" ];

  # UEFI boot with systemd-boot (ARM requires UEFI)
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # File systems are managed by disko

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
