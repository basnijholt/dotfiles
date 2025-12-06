{ ... }:

{
  networking.hostName = "dev-lxc";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
}
