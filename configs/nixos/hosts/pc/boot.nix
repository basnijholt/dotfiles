# Boot loader configuration with custom GRUB theme
{ config, pkgs, ... }:

{
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
  # fixBinary preloads qemu into kernel, required for sandboxed builds
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.binfmt.registrations.aarch64-linux.fixBinary = true;

  # Enable ZFS support (needed to provision ZFS-based hosts like pi4)
  boot.supportedFilesystems = [ "zfs" ];
  # TODO: remove pin when nixpkgs defaults to zfs_2_4
  # https://github.com/nixos/nixpkgs/blob/master/pkgs/top-level/all-packages.nix#L10124
  boot.zfs.package = pkgs.zfs_2_4; # 2.4.0 fixes SQLite/ftruncate delays (openzfs/zfs#14290)
}
