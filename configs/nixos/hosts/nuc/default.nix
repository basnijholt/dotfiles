{ lib, ... }:

{
  imports = [
    ../../modules/networking.nix
    ./desktop.nix
    ./services.nix
    ./system-packages.nix
  ];

  networking.hostName = lib.mkForce "nuc";
}
