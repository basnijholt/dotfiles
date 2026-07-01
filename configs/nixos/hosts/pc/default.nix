{ pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/desktop.nix
    ../../optional/audio.nix
    ../../optional/virtualization.nix
    ../../optional/gui-packages.nix
    ../../optional/large-packages.nix
    ../../optional/power.nix
    ../../optional/ups-client.nix
    ../../optional/wake-on-lan.nix
    ../../optional/nfs-docker.nix

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
    ./t3code.nix
    ./backup.nix
    ./nvidia-graphics.nix
    ./nvidia-undervolt.nix
    ./slurm.nix
  ];

  local.wakeOnLan.interface = "enp5s0";

  # Required for DDC/CI tools such as ddcutil to read monitor state, including
  # the active input source. This lets Hyprland automation distinguish between
  # the Dell being on DisplayPort and the Dell being switched to another input.
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; [
    ddcutil
  ];
}
