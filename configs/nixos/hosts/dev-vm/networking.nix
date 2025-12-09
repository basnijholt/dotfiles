{ ... }:

{
  networking.hostName = "dev-vm";
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.enable = true;
}
