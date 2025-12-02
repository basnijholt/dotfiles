{ ... }:

{
  networking.hostName = "dev-lxc";

  networking.nftables.enable = true;
  networking.firewall.enable = true;

  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; } # mosh
  ];
}
