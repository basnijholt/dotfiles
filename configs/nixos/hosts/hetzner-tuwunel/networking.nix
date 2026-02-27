# Hetzner Cloud networking for Tuwunel Matrix server
{ lib, ... }:

{
  networking.hostName = "hetzner-tuwunel";

  # systemd-networkd (required for Hetzner)
  systemd.network.enable = true;
  networking.useDHCP = lib.mkDefault false;

  systemd.network.networks."30-wan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      DHCP = "ipv4";
      DNS = [ "1.1.1.1" "8.8.8.8" ];
    };
  };

  # Firewall: SSH + HTTP/HTTPS (Caddy handles TLS)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };
}
