{ ... }:

{
  imports = [
    ./networking.nix
    ./system-packages.nix
    ./power.nix
  ];

  # Required for ZFS
  networking.hostId = "37a1d4a7";
}
