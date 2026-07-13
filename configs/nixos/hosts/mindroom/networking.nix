{ ... }:

{
  networking.hostName = "mindroom";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    80   # Caddy HTTP
    443  # Caddy HTTPS
  ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    8090  # Cinny frontend via Tailscale IP / MagicDNS
    8766  # MindRoom frontend/API via Tailscale IP / MagicDNS
  ];
}
