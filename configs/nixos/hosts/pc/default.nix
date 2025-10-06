{ ... }:

{
  imports = [
    ../../modules/boot.nix
    ../../modules/storage.nix
    ../../modules/networking.nix
    ../../modules/desktop.nix
    ../../modules/services.nix
    ../../modules/system-packages.nix
    ../../modules/keyboard-remap.nix
    ../../modules/gaming.nix
    ../../modules/debugging.nix
    ../../modules/ai.nix
    ../../modules/backup.nix
    ../../modules/nvidia-graphics.nix
    ../../modules/slurm.nix
  ];
}
