{ ... }:

{
  networking.hostName = "hp";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.networkmanager.enable = false;
  
  # Configure Bridge for Incus VMs/Containers
  networking.bridges = {
    "br0" = {
      interfaces = [ "eno1" ];
    };
  };
  
  networking.interfaces.br0.useDHCP = true;
  networking.interfaces.eno1.useDHCP = false;

  # Trust the bridge so VMs can do DHCP/DNS
  networking.firewall.trustedInterfaces = [ "br0" "incusbr0" ];

  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; } # mosh
  ];
}
