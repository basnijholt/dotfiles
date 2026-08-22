# OpenSpeedTest - local speed test server
#
# Simple Docker-based speed test for testing WiFi/network performance.
# Access from any browser (iPhone, etc.) at http://<ip>:8880
#
# Ports:
#   8880 - Local speed test (OpenSpeedTest)
#   8881 - Seattle speed test (proxied via Caddy)
{ ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers.openspeedtest = {
      image = "openspeedtest/latest";
      ports = [ "8880:3000" ];
      autoStart = true;
    };
  };
}
