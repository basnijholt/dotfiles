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
  virtualisation.docker.daemon.settings.dns = lib.mkForce ["192.168.1.2" "1.1.1.1" "1.0.0.1"];
}
