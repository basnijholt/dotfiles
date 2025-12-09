# Bootstrap SD Card Image for Raspberry Pi 3/4
# Usage:
#   nix build 'path:.#pi3-bootstrap.config.system.build.sdImage' --impure
#   nix build 'path:.#pi4-bootstrap.config.system.build.sdImage' --impure
#
# This creates a minimal bootable image with WiFi + SSH.
# After booting, see hosts/pi3/README.md or hosts/pi4/README.md for next steps.
{ lib, pkgs, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;
in
{
  imports = [
    ../common/nix.nix
    ../hosts/pi4/networking.nix
  ] ++ lib.optional (builtins.pathExists ../hosts/pi4/wifi.nix) ../hosts/pi4/wifi.nix;

  networking.hostName = lib.mkForce "pi-bootstrap";
  networking.hostId = "8425e349"; # Required for ZFS

  # Only ZFS and vfat (for boot) - disable others to shrink image
  # Default SD image enables cifs/ntfs/btrfs etc which pulls in samba (~600MB)
  boot.supportedFilesystems = lib.mkForce [ "vfat" "zfs" ];

  # Ensure WiFi driver loads (critical for headless)
  boot.kernelModules = [ "brcmfmac" ];

  # Don't compress for faster flashing
  sdImage.compressImage = false;

  system.stateVersion = "25.11";

  # Trust nixos user for bootstrap operations
  nix.settings.trusted-users = [ "root" "nixos" ];

  # SSH access for headless setup
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  # nixos user for interactive use
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "nixos";
    openssh.authorizedKeys.keys = sshKeys;
  };

  # Allow passwordless sudo for nixos user
  security.sudo.wheelNeedsPassword = false;

  # Minimal NetworkManager for WiFi (no VPN plugins, no GUI)
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager = {
    enable = true;
    plugins = lib.mkForce [];  # No VPN plugins - saves huge build time
  };

  # Essential tools
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    parted
    gptfdisk
  ];
}
