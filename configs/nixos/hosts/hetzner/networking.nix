# Hetzner Cloud networking configuration
{ lib, ... }:

{
  networking.hostName = "hetzner";

  # Use systemd-networkd (required for Hetzner's network setup)
  systemd.network.enable = true;
  networking.useDHCP = lib.mkDefault false;

  # Main network interface (enp1s0 on ARM)
  systemd.network.networks."30-wan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      DHCP = "ipv4";
      DNS = [ "1.1.1.1" "8.8.8.8" ]; # Explicit DNS (not local network)
    };
  };

  # Firewall - allow essential ports
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };
}
