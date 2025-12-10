# Docker Swarm HA cluster
# Usage:
#   Bootstrap manager: my.swarm.bootstrap = "br0";
#   Joining manager:   my.swarm.join = "br0";
{ config, lib, ... }:

let
  cfg = config.my.swarm;
  isBootstrap = cfg.bootstrap != null;
  isJoin = cfg.join != null;
  enabled = isBootstrap || isJoin;
  advertiseAddr = if isBootstrap then cfg.bootstrap else cfg.join;
in
{
  options.my.swarm = {
    bootstrap = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Interface to bootstrap swarm on (makes this the first manager).";
      example = "br0";
    };
    join = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Interface to join swarm on (joins hp.local as manager).";
      example = "eth0";
    };
  };

  config = lib.mkIf enabled {
    virtualisation.docker.enable = true;

    networking.firewall.allowedTCPPorts = [ 2377 7946 ];
    networking.firewall.allowedUDPPorts = [ 7946 4789 ];

    age.secrets.swarm-manager-token = lib.mkIf isJoin {
      file = ../secrets/swarm-manager.token.age;
    };

    systemd.services.swarm-init = lib.mkIf isBootstrap {
      description = "Initialize Docker Swarm";
      after = [ "docker.service" "network-online.target" ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        set -euo pipefail
        if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -qE 'active|pending'; then
          exit 0
        fi
        docker swarm init --advertise-addr ${advertiseAddr}
        mkdir -p /root/secrets && chmod 700 /root/secrets
        docker swarm join-token manager -q > /root/secrets/swarm-manager.token
        docker swarm join-token worker -q > /root/secrets/swarm-worker.token
        chmod 400 /root/secrets/swarm-*.token
      '';
    };

    systemd.services.swarm-join = lib.mkIf isJoin {
      description = "Join Docker Swarm";
      after = [ "docker.service" "network-online.target" ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        set -euo pipefail
        if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -qE 'active|pending'; then
          exit 0
        fi
        token="$(cat ${config.age.secrets.swarm-manager-token.path})"
        docker swarm join --token "$token" --advertise-addr ${advertiseAddr} hp.local:2377
      '';
    };
  };
}
