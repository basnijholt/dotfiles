# /etc/nixos/configuration.nix
# NixOS -- basnijholt/dotfiles

{ config, pkgs, ... }:

{
  imports = [
    ./modules/keyboard-remap.nix
    ./modules/boot.nix
    ./modules/storage.nix
    ./modules/networking.nix
    ./modules/gaming.nix
    ./modules/system-core.nix
    ./modules/nix.nix
    ./modules/nixpkgs.nix
    ./modules/user.nix
    ./modules/desktop.nix
    ./modules/nvidia-graphics.nix
    ./modules/ai.nix
    ./modules/backup.nix
    ./modules/services.nix
    ./modules/slurm.nix
    ./modules/system-packages.nix
    ./modules/home-manager.nix
    ./hardware-configuration.nix
  ];
  # The system state version is critical and should match the installed NixOS release.
  system.stateVersion = "25.05";
}
