{ lib, ... }:

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

  # Enable resolved for .local DNS (requires disabling useHostResolvConf in LXC)
  services.resolved.enable = lib.mkOverride 40 true;
  networking.useHostResolvConf = lib.mkForce false;
}
