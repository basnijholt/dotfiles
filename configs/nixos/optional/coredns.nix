# CoreDNS configuration - shared DNS zone definitions
#
# Primary: nuc (192.168.1.2)
# Secondary: hp (192.168.1.3)
#
# Both serve identical zone files for redundancy.
#
# Note: GL.iNet travel routers (OpenWrt) block .local queries by default (rfc6761.conf).
# To forward .local to CoreDNS:
# 1. Open LuCI: http://192.168.8.1:8080/cgi-bin/luci/admin/network/dhcp
#    (requires LuCI enabled via http://192.168.8.1/#/advanced)
# 2. Add `/local/192.168.1.2` to "DNS forwardings" in CFG01411C section, Save & Apply
# 3. WGCLIENT1 (port 2153) config is recreated on interface up, so create hotplug script:
#      cat > /etc/hotplug.d/iface/99-local-dns << 'EOF'
#      #!/bin/sh
#      [ "$ACTION" = "ifup" ] && [ "$INTERFACE" = "wgclient1" ] && {
#          uci add_list dhcp.wgclient1.server='/local/192.168.1.2'
#          uci commit dhcp
#          /etc/init.d/dnsmasq restart
#      }
#      EOF
#
# Test: dig @192.168.1.2 nuc.local +short  (should return 192.168.1.2)
{ config, pkgs, lib, ... }:

let
  cfg = config.local.coredns;

  # Wildcard IP for *.local, *.lab.nijho.lt, *.lab.mindroom.chat
  wildcardIP = "192.168.1.6";

  # DNS zone records - single source of truth
  dnsRecords = {
    nuc = "192.168.1.2";
    hp = "192.168.1.3";
    truenas = "192.168.1.4";
    pc = "192.168.1.5";
    docker = "192.168.1.6";
    docker-truenas = "192.168.1.6";
    pi4 = "192.168.1.7";
    pi3 = "192.168.1.8";
    vacuum = "192.168.1.10";
    tv = "192.168.1.11";
    leo = "192.168.1.12";
    tom = "192.168.1.13";
    switch = "192.168.1.14";
    meshcentral = "192.168.1.15";
    debian-truenas = "192.168.1.62";
    nix-cache = "192.168.1.145";
    printer = "192.168.1.234";
  };

  # CNAME records
  cnameRecords = {
    traefik = "docker";
    dns = "nuc";
  };

  # Generate A records from the dnsRecords attrset
  aRecordLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: ip: "    ${name}${lib.fixedWidthString (16 - lib.stringLength name) " " ""}3600  IN  A     ${ip}") dnsRecords
  );

  # Generate CNAME records
  cnameRecordLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: target: "    ${name}${lib.fixedWidthString (16 - lib.stringLength name) " " ""}3600  IN  CNAME ${target}") cnameRecords
  );

  localZone = pkgs.writeText "local.zone" ''
    $ORIGIN local.
    @               900   IN  SOA   ns hostadmin 1 900 300 604800 900
    @               3600  IN  NS    ns
    ns              3600  IN  A     ${cfg.listenIP}
    *               3600  IN  A     ${wildcardIP}
${aRecordLines}
${cnameRecordLines}
  '';

  labNijholtZone = pkgs.writeText "lab.nijho.lt.zone" ''
    $ORIGIN lab.nijho.lt.
    @   900   IN  SOA   ns hostadmin 1 900 300 604800 900
    @   3600  IN  NS    ns
    ns  3600  IN  A     ${cfg.listenIP}
    @   3600  IN  A     ${wildcardIP}
    *   3600  IN  A     ${wildcardIP}
  '';

  labMindroomChatZone = pkgs.writeText "lab.mindroom.chat.zone" ''
    $ORIGIN lab.mindroom.chat.
    @   900   IN  SOA   ns hostadmin 1 900 300 604800 900
    @   3600  IN  NS    ns
    ns  3600  IN  A     ${cfg.listenIP}
    *   3600  IN  A     ${wildcardIP}
  '';
in
{
  options.local.coredns = {
    enable = lib.mkEnableOption "CoreDNS local DNS server";

    listenIP = lib.mkOption {
      type = lib.types.str;
      description = "IP address for CoreDNS to bind to";
      example = "192.168.1.2";
    };

    extraSystemdDeps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra systemd units to wait for before starting CoreDNS";
      example = [ "sys-subsystem-net-devices-br0.device" ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.coredns = {
      enable = true;
      config = ''
        local {
          bind ${cfg.listenIP}
          file ${localZone}
        }

        lab.nijho.lt {
          bind ${cfg.listenIP}
          file ${labNijholtZone}
        }

        lab.mindroom.chat {
          bind ${cfg.listenIP}
          file ${labMindroomChatZone}
        }

        . {
          bind ${cfg.listenIP}
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
      after = [ "network-online.target" ] ++ cfg.extraSystemdDeps;
      wants = [ "network-online.target" ];
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "5s";
        StartLimitIntervalSec = 0;
      };
    };
  };
}
