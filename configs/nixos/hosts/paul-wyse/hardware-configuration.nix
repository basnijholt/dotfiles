# Hardware configuration for Dell Wyse 5070 thin client
#
# Intel Celeron J4105 (Gemini Lake), 4GB DDR4, 32GB eMMC
#
# NIC: Realtek RTL8111/8168 uses r8169 by default. If networking is
# unstable (link drops, poor throughput), switch to r8168 driver:
#   boot.blacklistedKernelModules = [ "r8169" ];
#   boot.extraModulePackages = [ config.boot.kernelPackages.r8168 ];
{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "uas" "sd_mod" "mmc_block" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.supportedFilesystems = [ "zfs" ];

  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      copyKernels = true;
    };
    efi.canTouchEfiVariables = true;
  };

  # Filesystems managed by disko.nix

  swapDevices = [ ];

  # Required for ZFS
  networking.hostId = "7ee014a7";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
