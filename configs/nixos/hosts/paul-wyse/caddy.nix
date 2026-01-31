# Caddy reverse proxy for Paul's Wyse 5070
#
# Proxies requests to home services via Tailscale
{ ... }:

{
  services.caddy = {
    enable = true;
    virtualHosts = {
      # DNS-based access (requires CoreDNS)
      "media.local:80" = {
        extraConfig = ''
          reverse_proxy 100.64.0.28:8096 {
            flush_interval -1
            transport http {
              read_buffer 128MB
              write_buffer 128MB
            }
          }
        '';
      };
      # Direct IP access (no DNS needed)
      ":8096" = {
        extraConfig = ''
          reverse_proxy 100.64.0.28:8096 {
            flush_interval -1
            transport http {
              read_buffer 128MB
              write_buffer 128MB
            }
          }
        '';
      };
      ":8880" = {
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
