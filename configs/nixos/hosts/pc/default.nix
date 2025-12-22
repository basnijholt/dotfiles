{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/desktop.nix
    ../../optional/audio.nix
    ../../optional/virtualization.nix
    ../../optional/printing.nix
    ../../optional/gui-packages.nix
    ../../optional/power.nix
    ../../optional/ups-client.nix
    ../../optional/wake-on-lan.nix

    # Host-specific modules (Tier 3)
    ./boot.nix
    ./storage.nix
    ./networking.nix
    ./package-overrides.nix
    ./1password.nix
    ./system-packages.nix
    ./keyboard-remap.nix
    ./gaming.nix
    ./debugging.nix
    ./ai.nix
    ./agent-cli.nix
    ./backup.nix
    ./nvidia-graphics.nix
    ./nvidia-undervolt.nix
    ./slurm.nix
  ];

  local.wakeOnLan.interface = "enp5s0";
}
