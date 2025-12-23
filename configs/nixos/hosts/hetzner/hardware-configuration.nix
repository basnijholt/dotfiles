# Hetzner Cloud VPS hardware configuration
#
# Generic QEMU/KVM guest configuration for Hetzner Cloud.
# Works for both x86_64 (CX/CPX) and aarch64 (CAX) instance types.
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

  # For aarch64 CAX instances: GPU drivers and serial console
  # Uncomment if using ARM instances:
  # boot.initrd.kernelModules = [ "virtio_gpu" ];
  # boot.kernelParams = [ "console=tty" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # For aarch64, change to:
  # nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
