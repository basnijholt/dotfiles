# Docker Swarm cluster configuration
#
# This module sets up Docker Swarm with:
# - Firewall rules for Swarm ports
# - Idempotent systemd services for init/join
# - Support for manager and worker roles
# - Optional agenix integration for secure token management
#
# With agenix (recommended):
#   1. Add host keys to secrets/secrets.nix
#   2. Encrypt tokens: cd secrets && agenix -e swarm-manager.token.age
#   3. Set my.swarm.useAgenix = true
#
# Without agenix (manual):
#   1. Generate tokens on bootstrap manager:
#      docker swarm join-token manager -q > /root/secrets/swarm-manager.token
#   2. Copy to joining nodes with permissions (0400 root:root)
#   3. Set managerTokenFile/workerTokenFile paths
{ config, lib, ... }:

let
  cfg = config.my.swarm;

  # Determine the token file path based on agenix usage
  managerTokenPath =
    if cfg.useAgenix
    then config.age.secrets.swarm-manager-token.path
    else cfg.managerTokenFile;

  workerTokenPath =
    if cfg.useAgenix
    then config.age.secrets.swarm-worker-token.path
    else cfg.workerTokenFile;

  tokenPath =
    if cfg.role == "manager"
    then managerTokenPath
    else workerTokenPath;
in
{
  options.my.swarm = {
    enable = lib.mkEnableOption "Docker Swarm";

    useAgenix = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use agenix for token management instead of manual files.";
    };

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
      description = "Path to file containing swarm manager join token (ignored if useAgenix=true).";
    };

    workerTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to file containing swarm worker join token (ignored if useAgenix=true).";
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

    # Agenix secrets for joining nodes (not the bootstrap manager)
    age.secrets = lib.mkIf (cfg.useAgenix && cfg.managerAddr != null) {
      swarm-manager-token = lib.mkIf (cfg.role == "manager") {
        file = ../secrets/swarm-manager.token.age;
        mode = "0400";
        owner = "root";
        group = "root";
      };
      swarm-worker-token = lib.mkIf (cfg.role == "worker") {
        file = ../secrets/swarm-worker.token.age;
        mode = "0400";
        owner = "root";
        group = "root";
      };
    };

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

        echo "Swarm initialized."
        echo "To use agenix: encrypt these tokens and add to secrets/"
        echo "To use manual: copy tokens to joining nodes"
      '';
    };

    # Join an existing swarm
    systemd.services.swarm-join = lib.mkIf (cfg.managerAddr != null) {
      description = "Join Docker Swarm";
      after = [ "docker.service" "network-online.target" ]
        ++ lib.optionals cfg.useAgenix [ "agenix.service" ];
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

        tokenFile="${tokenPath}"

        if [ -z "$tokenFile" ] || [ ! -f "$tokenFile" ]; then
          echo "Missing token file for role ${cfg.role}: $tokenFile" >&2
          ${if cfg.useAgenix then ''
            echo "Ensure the agenix secret is configured in secrets/secrets.nix" >&2
          '' else ''
            echo "Copy the token from the bootstrap manager first." >&2
          ''}
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
