# SD Card Installer for Raspberry Pi 4 (Minimal)
# Usage: nix build .#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage --impure
{ lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
    ../hosts/pi4/networking.nix
  ];

  # Import wifi.nix to bake credentials into the SD image
  imports = lib.optional (builtins.pathExists ../hosts/pi4/wifi.nix) ../hosts/pi4/wifi.nix;

  networking.hostName = lib.mkForce "pi4-bootstrap";

  # --- Minimal System Settings ---
  boot.supportedFilesystems = lib.mkForce [ "ext4" "vfat" ];
  sdImage.compressImage = false;
  hardware.enableRedistributableFirmware = true; # Required for WiFi
  system.stateVersion = "25.05";

  # --- Nix Configuration (Needed for installation) ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true; # For WiFi firmware

  # --- User & SSH Access ---
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
