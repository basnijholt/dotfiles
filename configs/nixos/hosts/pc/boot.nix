# Boot loader configuration with custom GRUB theme
{ config, pkgs, ... }:

{
  # Allow binfmt emulators inside nix sandbox (for cross-compilation)
  nix.settings.extra-sandbox-paths = [ "/run/binfmt" ];
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    useOSProber = true;
    device = "nodev";
    memtest86.enable = true;
    theme = pkgs.sleek-grub-theme.override {
      withStyle = "orange";
      withBanner = "Welcome Bas!";
    };
  };
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot2";
  };

  # Enable aarch64 emulation for building Raspberry Pi images
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Enable ZFS support (needed to provision ZFS-based hosts like pi4)
  boot.supportedFilesystems = [ "zfs" ];
}
