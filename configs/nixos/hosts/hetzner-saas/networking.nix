# Hetzner Cloud networking configuration for the MindRoom SaaS K3s host.
{ lib, ... }:

{
  networking.hostName = "hetzner-saas";

  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;
  networking.useDHCP = lib.mkDefault false;

  systemd.network.networks."30-wan" = {
    matchConfig.Name = "eth0";
    address = [ "46.62.174.103/32" ];
    networkConfig = {
      DNS = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };
    routes = [
      {
        Gateway = "172.31.1.1";
        GatewayOnLink = true;
      }
    ];
  };

  networking.nameservers = lib.mkForce [
    "1.1.1.1"
    "8.8.8.8"
    "100.100.100.100"
  ];

  networking.firewall = {
    enable = true;
    trustedInterfaces = [
      "cni0"
      "flannel.1"
    ];
    allowedTCPPorts = [
      22
      80
      443
      6443
    ];
    allowedUDPPorts = [ 8472 ];
    checkReversePath = "loose";
  };
}
