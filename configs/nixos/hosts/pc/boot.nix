# Boot loader configuration with custom GRUB theme
{ config, pkgs, ... }:

{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    useOSProber = true;
    device = "nodev";
    copyKernels = true;
    memtest86.enable = true;
    theme = pkgs.sleek-grub-theme.override {
      withStyle = "orange";
      withBanner = "Welcome Bas!";
    };
  };
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot";
  };

  # Enable aarch64 emulation for building Raspberry Pi images
  # fixBinary preloads qemu into kernel, required for sandboxed builds
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.binfmt.registrations.aarch64-linux.fixBinary = true;

  # Enable ZFS support (needed to provision ZFS-based hosts like pi4)
  boot.supportedFilesystems = [ "zfs" ];
}
