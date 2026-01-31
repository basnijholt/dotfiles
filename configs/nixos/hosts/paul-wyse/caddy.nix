# Caddy reverse proxy for Paul's Wyse 5070
#
# Proxies requests to home services via Tailscale
# media.local = remote Emby
# media2.local = LOCAL Jellyfin (with rclone VFS cache - better buffering)
# media3.local = remote Jellyfin
{ ... }:

{
  services.caddy = {
    enable = true;
    virtualHosts = {
      # Remote media server (Emby)
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
      # Speed test
      ":8880" = {
        extraConfig = ''
          reverse_proxy 100.64.0.28:8880
        '';
      };
      # LOCAL media server (Jellyfin with rclone cache)
      "media2.local:80" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8096 {
            flush_interval -1
          }
        '';
      };
      # Direct port access for local Jellyfin
      ":8098" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8096 {
            flush_interval -1
          }
        '';
      };
      # Remote media server (Jellyfin)
      "media3.local:80" = {
        extraConfig = ''
          reverse_proxy 100.64.0.28:8097 {
            flush_interval -1
            transport http {
              read_buffer 128MB
              write_buffer 128MB
            }
          }
        '';
      };
      ":8097" = {
        extraConfig = ''
          reverse_proxy 100.64.0.28:8097 {
            flush_interval -1
            transport http {
              read_buffer 128MB
              write_buffer 128MB
            }
          }
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
