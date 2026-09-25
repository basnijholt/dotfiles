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
  # Docker veth interfaces must not inherit the Incus uplink's DHCP policy.
  networking.useDHCP = lib.mkForce false;
  networking.interfaces.eth0.useDHCP = true;
  networking.firewall.allowedTCPPorts = [ 9001 ];
  # Tailnet traffic to Docker-published ports is forwarded, and Tailscale's
  # subnet-route SNAT would rewrite its source to the Docker bridge gateway.
  # Keep real 100.64.x sources so Traefik's allowlist sees who is connecting.
  services.tailscale.extraSetFlags = [ "--snat-subnet-routes=false" ];
  hardware.graphics.enable = true;
  services.syncthing.enable = lib.mkForce false;
  virtualisation.docker.daemon.settings.dns = lib.mkForce ["192.168.1.2" "192.168.1.3" "1.1.1.1"];
}
