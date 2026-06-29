{ lib, ... }:

{
  networking = {
    hostName = "nas";
    domain = "local";
    useDHCP = false;
    networkmanager.enable = false;
    nftables.enable = true;

    nameservers = lib.mkForce [
      "192.168.1.66"
      "8.8.8.8"
      "192.168.1.240"
    ];

    firewall = {
      enable = true;
      trustedInterfaces = [
        "br0"
        "incusbr0"
        "docker0"
      ];
    };
  };

  # Match the Docker/Incus bridge behavior used on pc. Docker may load
  # br_netfilter, but bridged Incus traffic should not traverse firewall chains.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.bridge.bridge-nf-call-iptables" = 0;
    "net.bridge.bridge-nf-call-ip6tables" = 0;
  };

  systemd.network = {
    enable = true;

    netdevs."20-br0".netdevConfig = {
      Kind = "bridge";
      Name = "br0";
      MACAddress = "e6:a9:ef:92:a4:76";
    };

    networks."30-enp4s0" = {
      matchConfig.Name = "enp4s0";
      networkConfig.Bridge = "br0";
      linkConfig.RequiredForOnline = "no";
    };

    networks."30-enp3s0" = {
      matchConfig.Name = "enp3s0";
      linkConfig.RequiredForOnline = "no";
    };

    networks."40-br0" = {
      matchConfig.Name = "br0";
      address = [ "192.168.1.4/24" ];
      networkConfig = {
        Gateway = "192.168.1.1";
        DNS = [
          "192.168.1.66"
          "8.8.8.8"
          "192.168.1.240"
        ];
        IPv6AcceptRA = true;
      };
      linkConfig = {
        RequiredForOnline = "routable";
        RequiredFamilyForOnline = "ipv4";
      };
    };
  };
}
