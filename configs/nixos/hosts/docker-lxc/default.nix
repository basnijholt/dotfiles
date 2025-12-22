{ lib, ... }:

{
  imports = [
    ../dev-lxc/default.nix
    ../dev-lxc/hardware-configuration.nix
    ./packages.nix
    ./rclone-b2-backup.nix
  ];

  networking.hostName = lib.mkForce "docker-lxc";
  hardware.graphics.enable = true;
  services.syncthing.enable = lib.mkForce false;
}
