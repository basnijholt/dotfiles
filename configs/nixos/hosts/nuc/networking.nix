{ ... }:

{
  networking.hostName = "nuc";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.networkmanager.enable = false;
  
  # Enable systemd-networkd for bridge configuration
  systemd.network.enable = true;
  
  # Configure Bridge for Incus VMs/Containers using systemd-networkd
  systemd.network = {
    netdevs = {
      "20-br0" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br0";
        };
      };
    };
    
    networks = {
      # Connect physical interface to bridge
      "30-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig.Bridge = "br0";
        linkConfig.RequiredForOnline = "enslaved";
      };
      
      # Configure bridge with DHCP
      "40-br0" = {
        matchConfig.Name = "br0";
        networkConfig.DHCP = "yes";
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  # Trust the bridge so VMs can do DHCP/DNS
  networking.firewall.trustedInterfaces = [ "br0" "incusbr0" ];

  networking.firewall.allowedTCPPorts = [ 8080 ]; # Kodi web interface
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; } # mosh
  ];
}
