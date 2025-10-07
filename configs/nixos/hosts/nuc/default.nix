{ lib, ... }:

{
  imports = [
    ../../modules/networking.nix
    ./networking.nix
    ./desktop.nix
    ./services.nix
    ./system-packages.nix
  ];

  networking.hostName = lib.mkForce "nuc";
}
