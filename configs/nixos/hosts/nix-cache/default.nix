{ lib, ... }:

{
  imports = [
    # LXC base configuration (Tier 1)
    ../../optional/lxc-container.nix

    # Optional modules (Tier 2)
    # Note: nix-cache is a headless build server, no desktop/audio
    ../../optional/virtualization.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./nix-build.nix
    ./harmonia.nix
    ./ncps.nix
    ./system-packages.nix
    ./auto-build.nix
  ];

  # Harmonia serves local /nix/store paths, so avoid automatic cleanup removing
  # cache contents. ncps has its own LRU for /var/lib/ncps.
  nix.gc.automatic = lib.mkForce false;
  nix.settings.min-free = lib.mkForce 0;
  nix.settings.max-free = lib.mkForce 0;
  virtualisation.docker.autoPrune.enable = lib.mkForce false;
}
