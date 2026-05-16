# Hetzner Cloud networking configuration for the MindRoom SaaS K3s host.
{ lib, ... }:

{
  networking.hostName = "hetzner-saas";

  systemd.network.enable = true;
  networking.useDHCP = lib.mkDefault false;

  systemd.network.networks."30-wan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      DHCP = "ipv4";
      DNS = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };
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
