# CoreDNS configuration for local DNS resolution
{ pkgs, ... }:

let
  # IP address for this DNS server (must match DHCP reservation)
  listenIP = "192.168.1.25";
  wildcardIP = "192.168.1.66";

  localZone = pkgs.writeText "local.zone" ''
    $ORIGIN local.
    @               900   IN  SOA   ns hostadmin 1 900 300 604800 900
    @               3600  IN  NS    ns
    ns              3600  IN  A     ${listenIP}
    *               3600  IN  A     ${wildcardIP}
    coredns         3600  IN  A     ${listenIP}
    dietpi          3600  IN  A     192.168.1.3
    docker          3600  IN  A     192.168.1.4
    docker-proxmox  3600  IN  A     192.168.1.4
    hp              3600  IN  A     192.168.1.26
    leo             3600  IN  A     192.168.1.6
    meshcentral     3600  IN  A     192.168.1.15
    nginx           3600  IN  A     192.168.1.4
    nix-cache       3600  IN  A     192.168.1.145
    nuc             3600  IN  A     ${listenIP}
    pc              3600  IN  A     192.168.1.143
    switch          3600  IN  A     192.168.1.87
    tom             3600  IN  A     192.168.1.188
    traefik         3600  IN  CNAME docker
    truenas         3600  IN  A     192.168.1.214
    ubuntu          3600  IN  A     192.168.1.102
    vacuum          3600  IN  A     192.168.1.10
  '';

  labNijholtZone = pkgs.writeText "lab.nijho.lt.zone" ''
    $ORIGIN lab.nijho.lt.
    @   900   IN  SOA   ns hostadmin 1 900 300 604800 900
    @   3600  IN  NS    ns
    ns  3600  IN  A     ${listenIP}
    @   3600  IN  A     ${wildcardIP}
    *   3600  IN  A     ${wildcardIP}
  '';

  labMindroomChatZone = pkgs.writeText "lab.mindroom.chat.zone" ''
    $ORIGIN lab.mindroom.chat.
    @   900   IN  SOA   ns hostadmin 1 900 300 604800 900
    @   3600  IN  NS    ns
    ns  3600  IN  A     ${listenIP}
    *   3600  IN  A     ${wildcardIP}
  '';
in
{
  services.coredns = {
    enable = true;
    config = ''
      local {
        bind ${listenIP}
        file ${localZone}
      }

      lab.nijho.lt {
        bind ${listenIP}
        file ${labNijholtZone}
      }

      lab.mindroom.chat {
        bind ${listenIP}
        file ${labMindroomChatZone}
      }

      . {
        bind ${listenIP}
        forward . 1.1.1.1 8.8.8.8
        cache 300
        errors
      }
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
}
