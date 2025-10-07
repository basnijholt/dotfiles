{ ... }:

{
  networking.hostName = "nuc";
  networking.useDHCP = true;
  networking.networkmanager.enable = false;
  networking.firewall.allowedTCPPorts = [ ];
}
