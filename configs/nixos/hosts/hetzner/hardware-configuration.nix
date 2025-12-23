# Hetzner Cloud VPS hardware configuration (ARM)
#
# Ampere Altra ARM64 guest configuration for Hetzner Cloud CAX series.
# Uses UEFI boot with ZFS root.
{ lib, modulesPath, pkgs, ... }:

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
  # TODO: remove pin when nixpkgs defaults to zfs_2_4
  # https://github.com/nixos/nixpkgs/blob/master/pkgs/top-level/all-packages.nix#L10124
  boot.zfs.package = pkgs.zfs_2_4; # 2.4.0 fixes SQLite/ftruncate delays (openzfs/zfs#14290)

  # UEFI boot with systemd-boot (ARM requires UEFI)
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # File systems are managed by disko

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
