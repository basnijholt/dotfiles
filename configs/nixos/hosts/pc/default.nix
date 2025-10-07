{ ... }:

{
  imports = [
    ./boot.nix
    ./storage.nix
    ./networking.nix
    ./services.nix
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
