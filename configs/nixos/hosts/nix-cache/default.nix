{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: nix-cache is a headless build server, no desktop/audio
    ../../optional/virtualization.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./nix-build.nix
    ./harmonia.nix
    ./system-packages.nix
    ./auto-build.nix
  ];
}
