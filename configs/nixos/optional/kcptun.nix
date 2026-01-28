# kcptun - UDP tunnel with FEC for high-latency/lossy networks
#
# This module sets up kcptun for improved transatlantic throughput.
# It uses Forward Error Correction (FEC) to recover from packet loss,
# enabling ~200-300 Mbps usable throughput on links where TCP collapses
# to ~2 Mbps due to high latency (263ms) and packet loss (5-11%).
#
# Usage:
#   services.kcptun.server.enable = true;  # On the media server (Seattle)
#   services.kcptun.client.enable = true;  # On the relay (Hetzner)
#
{ config, lib, pkgs, ... }:

let
  cfg = config.services.kcptun;

  # Build kcptun from source
  kcptun = pkgs.buildGoModule rec {
    pname = "kcptun";
    version = "20250612";

    src = pkgs.fetchFromGitHub {
      owner = "xtaci";
      repo = "kcptun";
      rev = "v${version}";
      sha256 = "sha256-AM50zJnGWADp/kleNHkdB27Ho+YY5TUtK/Nbo0JGoAQ=";
    };

    vendorHash = null; # Uses vendored dependencies

    subPackages = [ "client" "server" ];

    postInstall = ''
      mv $out/bin/client $out/bin/kcptun-client
      mv $out/bin/server $out/bin/kcptun-server
    '';

    meta = with lib; {
      description = "Secure tunnel based on KCP with FEC support";
      homepage = "https://github.com/xtaci/kcptun";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

in {
  options.services.kcptun = {
    server = {
      enable = lib.mkEnableOption "kcptun server";

      listenPort = lib.mkOption {
        type = lib.types.port;
        default = 29900;
        description = "UDP port for kcptun server to listen on";
      };

      targetHost = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Target host for forwarded connections";
      };

      targetPort = lib.mkOption {
        type = lib.types.port;
        default = 22;
        description = "Target port for forwarded connections";
      };

      key = lib.mkOption {
        type = lib.types.str;
        default = "kcptun-secret-key";
        description = "Pre-shared key for encryption";
      };

      # FEC parameters for lossy networks
      datashard = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "FEC data shards (higher = more data per FEC group)";
      };

      parityshard = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "FEC parity shards (higher = more redundancy, more overhead)";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--crypt" "aes"
          "--mode" "fast3"
          "--mtu" "1200"  # Must be under Tailscale's 1280 MTU
          "--sndwnd" "16384"  # Very large windows for 263ms RTT (BDP ~16MB)
          "--rcvwnd" "16384"
          "--nocomp"
        ];
        description = "Additional kcptun server arguments";
      };
    };

    client = {
      enable = lib.mkEnableOption "kcptun client";

      localPort = lib.mkOption {
        type = lib.types.port;
        default = 12948;
        description = "Local TCP port to listen on";
      };

      remoteHost = lib.mkOption {
        type = lib.types.str;
        description = "Remote kcptun server address";
      };

      remotePort = lib.mkOption {
        type = lib.types.port;
        default = 29900;
        description = "Remote kcptun server port";
      };

      key = lib.mkOption {
        type = lib.types.str;
        default = "kcptun-secret-key";
        description = "Pre-shared key for encryption (must match server)";
      };

      datashard = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "FEC data shards (must match server)";
      };

      parityshard = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "FEC parity shards (must match server)";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--crypt" "aes"
          "--mode" "fast3"
          "--mtu" "1200"  # Must be under Tailscale's 1280 MTU
          "--sndwnd" "16384"  # Very large windows for 263ms RTT (BDP ~16MB)
          "--rcvwnd" "16384"
          "--nocomp"
        ];
        description = "Additional kcptun client arguments";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.server.enable {
      environment.systemPackages = [ kcptun ];

      networking.firewall.allowedUDPPorts = [ cfg.server.listenPort ];

      systemd.services.kcptun-server = {
        description = "kcptun Server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = lib.concatStringsSep " " ([
            "${kcptun}/bin/kcptun-server"
            "--listen" ":${toString cfg.server.listenPort}"
            "--target" "${cfg.server.targetHost}:${toString cfg.server.targetPort}"
            "--key" cfg.server.key
            "--datashard" (toString cfg.server.datashard)
            "--parityshard" (toString cfg.server.parityshard)
          ] ++ cfg.server.extraArgs);
          Restart = "always";
          RestartSec = 5;

          # Security hardening
          DynamicUser = true;
          CapabilityBoundingSet = "";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
    })

    (lib.mkIf cfg.client.enable {
      environment.systemPackages = [ kcptun ];

      systemd.services.kcptun-client = {
        description = "kcptun Client";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = lib.concatStringsSep " " ([
            "${kcptun}/bin/kcptun-client"
            "--localaddr" ":${toString cfg.client.localPort}"
            "--remoteaddr" "${cfg.client.remoteHost}:${toString cfg.client.remotePort}"
            "--key" cfg.client.key
            "--datashard" (toString cfg.client.datashard)
            "--parityshard" (toString cfg.client.parityshard)
          ] ++ cfg.client.extraArgs);
          Restart = "always";
          RestartSec = 5;

          # Security hardening
          DynamicUser = true;
          CapabilityBoundingSet = "";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
    })
  ];
}
