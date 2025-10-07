{ ... }:

{
  imports = [
    ./boot.nix
    ./storage.nix
    ../../modules/networking.nix
    ../../modules/desktop.nix
    ./services.nix
    ./keyboard-remap.nix
    ./gaming.nix
    ./debugging.nix
    ./ai.nix
    ./backup.nix
    ./nvidia-graphics.nix
    ./slurm.nix
  ];
}
