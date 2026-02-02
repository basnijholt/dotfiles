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
      # Relative path server works from any IP/hostname
      servers = [
        {
          name = "Paul-Wyse";
          server = "/";
          dlURL = "backend/garbage";
          ulURL = "backend/empty";
          pingURL = "backend/empty";
          getIpURL = "backend/getIP";
        }
      ];
    };
  };

  # Override nginx to listen on 8880 without SSL
  services.nginx = {
    enable = true;
    virtualHosts."speed.local" = {
      listen = [{ addr = "0.0.0.0"; port = 8880; }];
      forceSSL = lib.mkForce false;
      enableACME = lib.mkForce false;
    };
  };
}
