{ ... }:

{
  networking.hostName = "nuc";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.useDHCP = true;
  networking.networkmanager.enable = false;
  networking.firewall.allowedTCPPorts = [ ];
}
