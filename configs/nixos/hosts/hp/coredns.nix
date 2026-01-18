# CoreDNS configuration - secondary DNS server
#
# Primary: nuc (192.168.1.2)
# Secondary: hp (192.168.1.3)
#
# Both serve identical zone files for redundancy.
{ pkgs, lib, ... }:

let
  # IP address for this DNS server
  listenIP = "192.168.1.3";
  wildcardIP = "192.168.1.6";

  localZone = pkgs.writeText "local.zone" ''
    $ORIGIN local.
    @               900   IN  SOA   ns hostadmin 1 900 300 604800 900
    @               3600  IN  NS    ns
    ns              3600  IN  A     ${listenIP}
    *               3600  IN  A     ${wildcardIP}
    nuc             3600  IN  A     192.168.1.2
    hp              3600  IN  A     192.168.1.3
    truenas         3600  IN  A     192.168.1.4
    pc              3600  IN  A     192.168.1.5
    docker          3600  IN  A     192.168.1.6
    docker-truenas  3600  IN  A     192.168.1.6
    pi4             3600  IN  A     192.168.1.7
    pi3             3600  IN  A     192.168.1.8
    vacuum          3600  IN  A     192.168.1.10
    tv              3600  IN  A     192.168.1.11
    leo             3600  IN  A     192.168.1.12
    tom             3600  IN  A     192.168.1.13
    switch          3600  IN  A     192.168.1.14
    meshcentral     3600  IN  A     192.168.1.15
    printer         3600  IN  A     192.168.1.234
    debian-truenas  3600  IN  A     192.168.1.62
    nix-cache       3600  IN  A     192.168.1.145
    traefik         3600  IN  CNAME docker
    dns             3600  IN  CNAME nuc
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

  # Ensure CoreDNS waits for network and restarts reliably
  systemd.services.coredns = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = "5s";
      StartLimitIntervalSec = 0;
    };
  };
}
