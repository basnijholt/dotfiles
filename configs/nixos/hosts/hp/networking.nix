{ ... }:

{
  networking.hostName = "hp";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.useDHCP = true;
  networking.networkmanager.enable = false;
  networking.firewall.allowedTCPPorts = [ 8080 ]; # Kodi web interface
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; } # mosh
  ];
}
