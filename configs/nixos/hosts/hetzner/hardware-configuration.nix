# Hetzner Cloud VPS hardware configuration
#
# Generic QEMU/KVM guest configuration for Hetzner Cloud.
# Uses legacy BIOS boot (not UEFI) with ZFS root.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Kernel modules for virtio (Hetzner uses KVM)
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.supportedFilesystems = [ "zfs" ];

  boot.loader = {
    grub = {
      enable = true;
      efiSupport = false;
      # copyKernels is required for ZFS: GRUB cannot read ZFS datasets directly,
      # so kernels must be copied to the boot partition where GRUB can access them.
      copyKernels = true;
    };
    systemd-boot.enable = false;
    efi.canTouchEfiVariables = false;
  };

  # File systems are managed by disko

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
