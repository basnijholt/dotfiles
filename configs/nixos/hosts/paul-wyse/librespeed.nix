# LibreSpeed - local speed test server
#
# Provides a local speed test endpoint for testing network performance.
# Uses librespeed-rust backend with nginx serving static files.
#
# Ports:
#   8880 - Local speed test (nginx → librespeed-rust on 8989)
#   8881 - Seattle speed test (proxied via Caddy)
{ lib, ... }:

{
  services.librespeed = {
    enable = true;
    domain = "speed.local";
    settings = {
      worker_threads = 1; # Minimal for thin client
      database_type = "none"; # No persistent results needed
    };
    frontend = {
      enable = true;
      pageTitle = "Paul Speed Test";
      contactEmail = "basnijholt@gmail.com";
      servers = [
        {
          name = "Local";
          server = "/";
          dlURL = "backend/garbage";
          ulURL = "backend/empty";
          pingURL = "backend/empty";
          getIpURL = "backend/getIP";
        }
      ];
    };
  };

  # Enable nginx and override to listen on 8880 without SSL (Caddy uses 80)
  services.nginx = {
    enable = true;
    virtualHosts."speed.local" = {
      listen = [{ addr = "0.0.0.0"; port = 8880; }];
      forceSSL = lib.mkForce false;
      enableACME = lib.mkForce false;
    };
  };
}
