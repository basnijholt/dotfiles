{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: HP is a headless server, so no desktop/audio/gui-packages
    ../../optional/virtualization.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./system-packages.nix
    ./power.nix
  ];

  # Required for ZFS
  networking.hostId = "37a1d4a7";
}
