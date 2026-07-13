# Hardware configuration for the CWWK CW-Q670-NAS.
#
# Disko manages only the boot disk layout in disko.nix. The existing data pools
# (`tank` and `ssd`) are imported by name in storage.nix and must not be
# formatted during migration.
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "sd_mod"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "i915"
    "kvm-intel"
  ];
  boot.extraModulePackages = [ ];

  boot.supportedFilesystems = [ "zfs" ];

  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      copyKernels = true;
      configurationLimit = 5;
    };
    efi.canTouchEfiVariables = true;
  };

  # File systems are managed by disko.nix.

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
