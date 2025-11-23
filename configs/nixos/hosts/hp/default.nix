{ ... }:

{
  imports = [
    ./networking.nix
    ./system-packages.nix
    ./kodi.nix
    ./power.nix
  ];

  # Required for ZFS
  networking.hostId = "37a1d4a7";
}
