{ ... }:

{
  networking.hostName = "hp";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.useDHCP = true;
  networking.networkmanager.enable = false;
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; } # mosh
  ];

  networking.nat = {
    enable = true;
    externalInterface = "wlp7s0";
    internalInterfaces = [ "incusbr0" ];
    forwardPorts = [
      { sourcePort = 8123; destination = "10.5.28.161:8123"; proto = "tcp"; }
    ];
  };
}
