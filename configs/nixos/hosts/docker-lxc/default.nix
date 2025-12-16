{ lib, ... }:

{
  imports = [
    ../dev-lxc/default.nix
    ../dev-lxc/hardware-configuration.nix
  ];

  networking.hostName = lib.mkForce "docker-lxc";
  hardware.graphics.enable = true;
}
