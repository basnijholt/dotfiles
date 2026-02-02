# LibreSpeed - local speed test server
#
# Provides a local speed test endpoint for testing network performance.
# Uses librespeed-rust which is lightweight and suitable for thin clients.
#
# Ports:
#   8880 - Local speed test (this server)
#   8881 - Seattle speed test (proxied via Caddy)
{ ... }:

{
  services.librespeed = {
    enable = true;
    settings = {
      listen_port = 8880;
      bind_address = "0.0.0.0";
      worker_threads = 1; # Minimal for thin client
      database_type = "none"; # No persistent results needed
    };
    frontend = {
      enable = true;
      useNginx = false; # Serve assets directly, no nginx needed
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
}
