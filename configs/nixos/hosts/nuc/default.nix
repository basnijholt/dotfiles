{ lib, ... }:

{
  imports = [
    ../../modules/networking.nix
    ./networking.nix
    ../../modules/desktop.nix
    ./services.nix
    ./system-packages.nix
  ];

  networking.hostName = lib.mkForce "nuc";
}
