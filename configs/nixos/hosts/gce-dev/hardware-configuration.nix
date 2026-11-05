# Google Compute Engine x86_64 guest configuration (gen3/4 machines: NVMe
# Hyperdisk + gVNIC, UEFI firmware).
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
  ];
  boot.kernelModules = [ "gve" ];
  boot.extraModulePackages = [ ];

  # GCE serial console is ttyS0 (last console= wins as /dev/console).
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
    "net.ifnames=0"
  ];

  boot.supportedFilesystems = [ "zfs" ];

  # GCE NVRAM is not something to rely on: bootctl also installs the
  # removable-media fallback (\EFI\BOOT\BOOTX64.EFI), which the firmware boots.
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    efi = {
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot";
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
