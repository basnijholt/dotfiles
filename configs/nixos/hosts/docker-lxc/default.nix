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
  # Containers reach this host through its own address (Uptime Kuma checking lab URLs,
  # cf's Kuma sync calling 192.168.1.6:3001). Docker relays that hairpin traffic through
  # the host's input chain, where the firewall would drop it. Docker networks: 172.16.0.0/12.
  networking.firewall.extraInputRules = "ip saddr 172.16.0.0/12 accept";
  # compose-farm opens an SSH connection per stack in parallel; the LXC profile's
  # socket-activated sshd would drop everything past 64 concurrent connections.
  systemd.sockets.sshd.socketConfig.MaxConnections = 256;
  # Tailnet traffic to Docker-published ports is forwarded, and Tailscale's
  # subnet-route SNAT would rewrite its source to the Docker bridge gateway.
  # Keep real 100.64.x sources so Traefik's allowlist sees who is connecting.
  services.tailscale.extraSetFlags = [ "--snat-subnet-routes=false" ];
  hardware.graphics.enable = true;
  services.syncthing.enable = lib.mkForce false;
  virtualisation.docker.daemon.settings.dns = lib.mkForce ["192.168.1.2" "192.168.1.3" "1.1.1.1"];
}
