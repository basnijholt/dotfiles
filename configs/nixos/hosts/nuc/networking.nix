{ ... }:

{
  networking.hostName = "nuc";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.networkmanager.enable = false;
  
  # Configure Bridge for Incus VMs/Containers
  networking.bridges = {
    "br0" = {
      interfaces = [ "eno1" ];
      stp = false; # Disable STP to avoid startup delays/timeouts on consumer routers
    };
  };
  
  networking.interfaces.br0.useDHCP = true;
  
  # Physical interface is a bridge member, no IP
  networking.interfaces.eno1.useDHCP = false;
  networking.interfaces.eno1.ipv4.addresses = [];

  # Trust the bridge so VMs can do DHCP/DNS
  networking.firewall.trustedInterfaces = [ "br0" "incusbr0" ];

  networking.firewall.allowedTCPPorts = [ 8080 ]; # Kodi web interface
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; } # mosh
  ];
}
