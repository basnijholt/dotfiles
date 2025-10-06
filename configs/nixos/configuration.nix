# /etc/nixos/configuration.nix
# NixOS -- basnijholt/dotfiles

{ config, pkgs, ... }:

{
  imports = [
    ./kinto.nix
    (builtins.path { path = ./modules/boot.nix; name = "boot.nix"; })
    (builtins.path { path = ./modules/storage.nix; name = "storage.nix"; })
    (builtins.path { path = ./modules/networking.nix; name = "networking.nix"; })
    (builtins.path { path = ./modules/audio.nix; name = "audio.nix"; })
    (builtins.path { path = ./modules/gaming.nix; name = "gaming.nix"; })
    (builtins.path { path = ./modules/system-basics.nix; name = "system-basics.nix"; })
    (builtins.path { path = ./modules/nix.nix; name = "nix.nix"; })
    (builtins.path { path = ./modules/nixpkgs.nix; name = "nixpkgs.nix"; })
    (builtins.path { path = ./modules/security.nix; name = "security.nix"; })
    (builtins.path { path = ./modules/user.nix; name = "user.nix"; })
    (builtins.path { path = ./modules/desktop.nix; name = "desktop.nix"; })
    (builtins.path { path = ./modules/gpu.nix; name = "gpu.nix"; })
    (builtins.path { path = ./modules/virtualization.nix; name = "virtualization.nix"; })
    (builtins.path { path = ./modules/ai.nix; name = "ai.nix"; })
    (builtins.path { path = ./modules/backup.nix; name = "backup.nix"; })
    (builtins.path { path = ./modules/services.nix; name = "services.nix"; })
    (builtins.path { path = ./modules/slurm.nix; name = "slurm.nix"; })
    (builtins.path { path = ./modules/system-packages.nix; name = "system-packages.nix"; })
    (builtins.path { path = ./modules/wayland-nvidia-workaround.nix; name = "wayland-nvidia-workaround.nix"; })
    (builtins.path { path = ./modules/home-manager.nix; name = "home-manager.nix"; })
    ./hardware-configuration.nix
  ];
  # The system state version is critical and should match the installed NixOS release.
  system.stateVersion = "25.05";
}
