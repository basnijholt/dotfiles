# Hetzner Cloud networking for Tuwunel Matrix server
{ lib, ... }:

{
  networking.hostName = "hetzner-matrix";
  # Here rather than in default.nix so the bootstrap config, which imports
  # this file, installs with the same hostId the pool is later imported with.
  networking.hostId = "a1b2c3d4";

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
