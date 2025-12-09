# Bootstrap SD Card Image for Raspberry Pi 3/4
# Usage:
#   nix build 'path:.#pi3-bootstrap.config.system.build.sdImage' --impure
#   nix build 'path:.#pi4-bootstrap.config.system.build.sdImage' --impure
#
# This creates a minimal bootable image with WiFi + SSH.
# After booting, see hosts/pi3/README.md or hosts/pi4/README.md for next steps.
{ lib, pkgs, ... }:

{
  # Import networking.nix (tracked) which conditionally imports wifi.nix (gitignored)
  imports = [
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

  system.stateVersion = "25.05";

  # Nix configuration - include local cache for faster installs
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "nixos" ];
    # Use binary caches to avoid slow ARM compilation
    substituters = [
      "https://cache.nixos.org/"
      "http://nix-cache.local:5000"
      "https://nix-community.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "build-vm-1:CQeZikX76TXVMm+EXHMIj26lmmLqfSxv8wxOkwqBb3g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  # SSH access for headless setup
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMRmEP/ZUShYdZj/h3vghnuMNgtWExV+FEZHYyguMkX basnijholt@blink"
  ];

  # nixos user for interactive use
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "nixos";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMRmEP/ZUShYdZj/h3vghnuMNgtWExV+FEZHYyguMkX basnijholt@blink"
    ];
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
