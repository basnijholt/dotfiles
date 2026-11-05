# GCE networking: DHCP on gVNIC (eth0), metadata server for DNS and NTP.
{ lib, ... }:

{
  networking.hostName = "gce-dev";
  networking.hostId = "3dca0566";

  networking.useDHCP = false;
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
    # GCE VPC MTU is 1460; DHCP advertises it.
    dhcpV4Config.UseMTU = true;
  };

  # The LAN resolvers from common/core.nix are unreachable here.
  networking.nameservers = lib.mkForce [
    "169.254.169.254"
    "1.1.1.1"
    "100.100.100.100"
  ];
  networking.timeServers = [ "metadata.google.internal" ];

  # Incus (optional/virtualization.nix) requires nftables.
  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 41641 ]; # Tailscale direct connections
    checkReversePath = "loose";
  };
}
