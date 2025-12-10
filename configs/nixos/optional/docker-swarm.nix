# Docker Swarm cluster configuration
#
# This module sets up Docker Swarm with:
# - Firewall rules for Swarm ports
# - Idempotent systemd services for init/join
# - Support for manager and worker roles
#
# Token handling: Tokens are read from files outside the Nix store.
# Generate tokens on the bootstrap manager:
#   docker swarm join-token manager -q > /root/secrets/swarm-manager.token
#   docker swarm join-token worker -q > /root/secrets/swarm-worker.token
# Then copy to joining nodes with appropriate permissions (0400 root:root).
{ config, lib, ... }:

let
  cfg = config.my.swarm;
in
{
  options.my.swarm = {
    enable = lib.mkEnableOption "Docker Swarm";

    role = lib.mkOption {
      type = lib.types.enum [ "manager" "worker" ];
      default = "worker";
      description = "Swarm node role.";
    };

    advertiseAddr = lib.mkOption {
      type = lib.types.str;
      description = "IP or interface for swarm advertise-addr.";
      example = "192.168.1.10";
    };

    managerAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Manager address to join (null = bootstrap manager).";
    };

    managerTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to file containing swarm manager join token.";
    };

    workerTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to file containing swarm worker join token.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure Docker is enabled
    virtualisation.docker.enable = true;

    # Swarm ports
    # - TCP 2377: cluster management
    # - TCP/UDP 7946: node discovery/gossip
    # - UDP 4789: overlay networking (VXLAN)
    networking.firewall.allowedTCPPorts = [ 2377 7946 ];
    networking.firewall.allowedUDPPorts = [ 7946 4789 ];

    # Initialize a new swarm (only on the bootstrap manager)
    systemd.services.swarm-init = lib.mkIf (cfg.role == "manager" && cfg.managerAddr == null) {
      description = "Initialize Docker Swarm (bootstrap manager)";
      after = [ "docker.service" "network-online.target" ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        # If already in a swarm, do nothing
        if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -qE 'active|pending'; then
          echo "Already in swarm, skipping init"
          exit 0
        fi

        echo "Initializing Docker Swarm..."
        docker swarm init --advertise-addr ${cfg.advertiseAddr}

        # Create secrets directory if it doesn't exist
        mkdir -p /root/secrets
        chmod 700 /root/secrets

        # Export tokens for other nodes to use
        echo "Exporting join tokens to /root/secrets/"
        docker swarm join-token manager -q > /root/secrets/swarm-manager.token
        docker swarm join-token worker -q > /root/secrets/swarm-worker.token
        chmod 400 /root/secrets/swarm-*.token

        echo "Swarm initialized. Copy tokens to joining nodes."
      '';
    };

    # Join an existing swarm
    systemd.services.swarm-join = lib.mkIf (cfg.managerAddr != null) {
      description = "Join Docker Swarm";
      after = [ "docker.service" "network-online.target" ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        # If already in a swarm, do nothing
        state="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)"
        if echo "$state" | grep -qE 'active|pending'; then
          echo "Already in swarm, skipping join"
          exit 0
        fi

        tokenFile="${if cfg.role == "manager" then cfg.managerTokenFile else cfg.workerTokenFile}"

        if [ -z "$tokenFile" ] || [ ! -f "$tokenFile" ]; then
          echo "Missing token file for role ${cfg.role}: $tokenFile" >&2
          echo "Copy the token from the bootstrap manager first." >&2
          exit 1
        fi

        token="$(cat "$tokenFile")"

        echo "Joining Docker Swarm as ${cfg.role}..."
        docker swarm join \
          --token "$token" \
          --advertise-addr ${cfg.advertiseAddr} \
          ${cfg.managerAddr}:2377

        echo "Successfully joined swarm"
      '';
    };
  };
}
