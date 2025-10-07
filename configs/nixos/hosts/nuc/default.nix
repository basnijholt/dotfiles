{ lib, ... }:

{
  imports = [
    ./networking.nix
    ./services.nix
    ./system-packages.nix
  ];

  networking.hostName = lib.mkForce "nuc";
}
