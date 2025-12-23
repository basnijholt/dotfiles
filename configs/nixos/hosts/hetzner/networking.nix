# Hetzner Cloud networking configuration
#
# Hetzner provides:
# - IPv4: /32 subnet via DHCP (or static with onlink gateway)
# - IPv6: /64 subnet (must be configured statically)
#
# Update the IPv6 address from your Hetzner Cloud Console.
{ lib, ... }:

{
  networking.hostName = "hetzner";

  # Use systemd-networkd (required for Hetzner's network setup)
  systemd.network.enable = true;
  networking.useDHCP = lib.mkDefault false;

  # Main network interface
  # Check with 'ip addr' - usually ens3 (amd64) or enp1s0 (arm64)
  systemd.network.networks."30-wan" = {
    matchConfig.Name = "en* eth*"; # Match any ethernet interface
    networkConfig = {
      DHCP = "ipv4"; # Get IPv4 via DHCP
      DNS = [ "1.1.1.1" "8.8.8.8" ]; # Cloudflare + Google DNS
    };

    # IPv6 must be configured statically
    # Replace with your assigned /64 subnet from Hetzner Console
    address = [
      # "2a01:4f8:xxxx:xxxx::1/64"  # Uncomment and set your IPv6
    ];
    routes = [
      { Gateway = "fe80::1"; } # IPv6 gateway (same for all Hetzner)
    ];
  };

  # Firewall - allow essential ports
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      80 # HTTP
      443 # HTTPS
    ];
  };
}
