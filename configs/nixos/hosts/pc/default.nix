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

  # Required for DDC/CI tools such as ddcutil to read monitor state (e.g. the
  # active input source) for manual diagnostics. Display automation no longer
  # depends on it; Sunshine drives dummy-output switching via sunshine-mode.sh.
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; [
    ddcutil
  ];
}
