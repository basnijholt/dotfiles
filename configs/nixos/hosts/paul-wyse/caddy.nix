# Caddy reverse proxy for Paul's Wyse 5070
#
# Proxies .local domains to home services via Tailscale
{ ... }:

{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "media.local:80" = {
        extraConfig = ''
          reverse_proxy 100.64.0.28:8096
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
