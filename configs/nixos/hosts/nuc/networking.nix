{ config, pkgs, ... }:

{
  networking.hostName = "nuc";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.networkmanager.enable = false;

  # Don’t let legacy networking do DHCP; we’ll use systemd-networkd instead
  networking.useDHCP = false;

  # Firewall
  networking.firewall.allowedTCPPorts = [ 8080 ]; # Kodi web interface
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; } # mosh
  ];

  # Trust incusbr0; you *can* add "br0" here if you explicitly want LAN to bypass firewall
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  # systemd-networkd + bridge
  systemd.network = {
    enable = true;
    # optional but nice so network-online doesn't block forever
    wait-online.anyInterface = true;

    # Define the bridge device br0
    netdevs."20-br0" = {
      netdevConfig = {
        Kind = "bridge";
        Name = "br0";
      };
    };

    networks = {
      # Attach physical NIC eno1 to br0
      "30-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig.Bridge = "br0";
        linkConfig.RequiredForOnline = "enslaved";
      };

      # Put DHCP on br0 (host IP comes from router on the bridge)
      "40-br0" = {
        matchConfig.Name = "br0";

        networkConfig = {
          DHCP = "ipv4";        # or "yes" if you want IPv6 DHCP too
          IPv6AcceptRA = true;  # keep if you use IPv6
        };

        linkConfig.RequiredForOnline = "routable";
      };
    };
  };
}
