# /etc/nixos/configuration.nix
# NixOS -- basnijholt/dotfiles

{ config, pkgs, ... }:

{
  imports = [
    ./modules/system-core.nix
    ./modules/nix.nix
    ./modules/nixpkgs.nix
    ./modules/user.nix
    ./modules/desktop.nix
    ./modules/services.nix
    ./modules/system-packages.nix
    ./modules/home-manager.nix
  ];
  # The system state version is critical and should match the installed NixOS release.
  system.stateVersion = "25.05";
}
