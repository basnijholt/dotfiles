# SD Card Installer for Raspberry Pi 4
# This generates a bootable SD image with SSH keys and WiFi credentials baked in.
#
# Usage:
#   nix build .#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage --impure
{ lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
    ../common/core.nix
    ../common/nix.nix
    ../common/nixpkgs.nix
    ../common/user.nix
    ../common/services.nix
    ../hosts/pi4/networking.nix
  ];

  # Import wifi.nix to bake credentials into the SD image
  imports = lib.optional (builtins.pathExists ../hosts/pi4/wifi.nix) ../hosts/pi4/wifi.nix;

  networking.hostName = lib.mkForce "pi4-bootstrap";

  # Disable ZFS for bootstrap image (runs on ext4 SD card)
  boot.supportedFilesystems = lib.mkForce [ "ext4" "vfat" ];

  # Compress image with zstd for faster flashing? No, uncompressed is faster to build.
  sdImage.compressImage = false;
}
