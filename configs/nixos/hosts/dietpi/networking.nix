# Network configuration for Raspberry Pi 4
{ ... }:

{
  networking.hostName = "dietpi";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.networkmanager.enable = false;

  # Systemd-networkd for simple headless server
  networking.useDHCP = false;
  systemd.network.enable = true;

  # Match any ethernet interface (eth0, end0, enp*, etc.)
  systemd.network.networks."10-ethernet" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
    linkConfig.RequiredForOnline = "routable";
  };

  # Mosh support for flaky connections
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; }
  ];
}
