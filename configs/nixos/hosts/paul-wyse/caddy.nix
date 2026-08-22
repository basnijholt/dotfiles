# Caddy reverse proxy for Paul's Wyse 5070
#
# Proxies requests to home services via Tailscale
{ ... }:

{
  services.caddy = {
    enable = true;
    virtualHosts = {
      # Speed test - Seattle (home server via Tailscale)
      ":8881" = {
        extraConfig = ''
          reverse_proxy 100.64.0.28:8880
        '';
      };
      # Speed test domains
      "speed.local:80" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8880
        '';
      };
      "speed-sea.local:80" = {
        extraConfig = ''
          reverse_proxy 100.64.0.28:8880
        '';
      };
    };
  };

  # Ensure Caddy starts after Tailscale is connected
  systemd.services.caddy = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };
}
