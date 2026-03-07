{ ... }:

{
  networking.hostName = "mindroom";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    80   # Caddy HTTP
    443  # Caddy HTTPS
  ];
}
