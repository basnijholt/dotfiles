# SD Card Installer for Raspberry Pi 4
# Usage: nix build .#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage
#
# This module is used with nixos-raspberrypi.lib.nixosInstaller which provides:
# - raspberry-pi-4.base (kernel, firmware, bootloader)
# - sd-image module
# - installer utilities
{ lib, pkgs, ... }:

{
  imports = [
    ../hosts/pi4/networking.nix
  ] ++ lib.optional (builtins.pathExists ../hosts/pi4/wifi.nix) ../hosts/pi4/wifi.nix;

  networking.hostName = lib.mkForce "pi4-bootstrap";
  networking.hostId = "8425e349"; # Required for ZFS

  # ZFS support for installation target
  boot.supportedFilesystems = [ "zfs" ];

  # Ensure WiFi driver loads (critical for headless)
  boot.kernelModules = [ "brcmfmac" ];

  # Don't compress for faster flashing
  sdImage.compressImage = false;

  system.stateVersion = "25.05";

  # Nix configuration for running nixos-anywhere
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # SSH access for installation
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMRmEP/ZUShYdZj/h3vghnuMNgtWExV+FEZHYyguMkX basnijholt@blink"
  ];

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Essential tools for installation/debugging
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
  ];
}
