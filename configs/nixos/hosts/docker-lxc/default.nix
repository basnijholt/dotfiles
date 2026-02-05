{ lib, ... }:

{
  imports = [
    ../dev-lxc/default.nix
    ../../optional/lxc-container.nix
    ./packages.nix
    ./rclone-b2-backup.nix
    ./github-backup-sync.nix
  ];

  networking.hostName = lib.mkForce "docker-lxc";
  networking.firewall.allowedTCPPorts = [ 9001 ];
  hardware.graphics.enable = true;
  services.syncthing.enable = lib.mkForce false;
  virtualisation.docker.daemon.settings.dns = lib.mkForce ["192.168.1.2" "192.168.1.3" "1.1.1.1"];
}
