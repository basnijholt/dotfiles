{ lib, ... }:

{
  imports = [
    ../dev-lxc/default.nix
    ../dev-lxc/hardware-configuration.nix
    ./packages.nix
    ./rclone-b2-backup.nix
    ./github-backup-sync.nix
  ];

  networking.hostName = lib.mkForce "docker-lxc";
  networking.firewall.allowedTCPPorts = [ 9001 ];
  hardware.graphics.enable = true;
  services.syncthing.enable = lib.mkForce false;

  # Enable resolved for .local DNS (requires disabling useHostResolvConf in LXC)
  services.resolved.enable = lib.mkOverride 40 true;
  networking.useHostResolvConf = lib.mkForce false;
  virtualisation.docker.daemon.settings.dns = lib.mkForce ["192.168.1.2" "192.168.1.3" "1.1.1.1"];
}
