# Docker Swarm HA: my.swarm.bootstrap = "br0"; or my.swarm.join = "br0";
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.swarm;
  addr = cfg.bootstrap or cfg.join;
  oneshot = {
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      config.virtualisation.docker.package
      pkgs.iproute2
      pkgs.gawk
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
  inSwarm = "docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -qxE 'active|pending'";
in
{
  options.my.swarm = with lib; {
    bootstrap = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "br0";
    };
    join = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "eth0";
    };
  };

  config = lib.mkIf (addr != null) {
    virtualisation.docker.enable = true;
    networking.firewall = {
      allowedTCPPorts = [
        2377
        7946
      ];
      allowedUDPPorts = [
        7946
        4789
      ];
    };
    age.secrets.swarm-manager-token = lib.mkIf (cfg.join != null) {
      file = ../secrets/swarm-manager.token.age;
    };

    systemd.services.swarm-init = lib.mkIf (cfg.bootstrap != null) (
      oneshot
      // {
        script = ''
          set -euo pipefail
          ${inSwarm} && exit 0
          ADDR=$(ip -4 addr show ${cfg.bootstrap} | awk '/inet / {print $2}' | cut -d/ -f1)
          docker swarm init --advertise-addr "$ADDR"
          install -d -m700 /root/secrets
          docker swarm join-token manager -q > /root/secrets/swarm-manager.token
          docker swarm join-token worker -q > /root/secrets/swarm-worker.token
          chmod 400 /root/secrets/swarm-*.token
        '';
      }
    );

    systemd.services.swarm-join = lib.mkIf (cfg.join != null) (
      oneshot
      // {
        script = ''
          set -euo pipefail
          ${inSwarm} && exit 0
          ADDR=$(ip -4 addr show ${cfg.join} | awk '/inet / {print $2}' | cut -d/ -f1)
          docker swarm join --token "$(cat ${config.age.secrets.swarm-manager-token.path})" \
            --advertise-addr "$ADDR" hp.local:2377
        '';
      }
    );
  };
}
