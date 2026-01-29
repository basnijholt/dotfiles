# Paul's Wyse 5070 networking configuration
{ lib, ... }:

{
  networking.hostName = "paul-wyse";

  # Use systemd-networkd
  systemd.network.enable = true;
  networking.useDHCP = lib.mkDefault false;

  # Main network interface - DHCP on any ethernet
  systemd.network.networks."30-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      DHCP = "ipv4";
      # Use local CoreDNS for DNS resolution
      DNS = [ "127.0.0.1" ];
    };
  };

  # Firewall - allow DNS (for local network) and HTTP (for reverse proxy)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 53 80 ];
    allowedUDPPorts = [ 53 ];
  };
}
