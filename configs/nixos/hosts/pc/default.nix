{ ... }:

{
  imports = [
    ./boot.nix
    ./storage.nix
    ./networking.nix
    ./1password.nix
    ./system-packages.nix
    ./keyboard-remap.nix
    ./gaming.nix
    ./debugging.nix
    ./ai.nix
    ./backup.nix
    ./nvidia-graphics.nix
    ./slurm.nix
  ];
}
