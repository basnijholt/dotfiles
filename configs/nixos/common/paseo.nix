# Paseo — daemon and web UI for running AI coding agents (Claude/Codex/OpenCode) from any device.
# The CLI is managed outside Nix by scripts/sync-bun.sh.
{ config, lib, pkgs, ... }:

let
  cfg = config.local.paseo;
  homeDir = config.users.users.basnijholt.home;
  bunBin = "${homeDir}/.bun/bin";
  systemBin = "/run/current-system/sw/bin";
  paseoHome = "${homeDir}/.paseo";
in
{
  options.local.paseo = {
    enable = lib.mkEnableOption "the Paseo daemon user service";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the Paseo daemon listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
      description = "TCP port on which the Paseo daemon listens.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.paseo = {
      enable = true;
      description = "Paseo daemon (AI coding agent web GUI)";
      wantedBy = [ "default.target" ];
      environment = {
        PATH = lib.mkForce "${bunBin}:${systemBin}";
        PASEO_HOME = paseoHome;
        PASEO_LISTEN = "${cfg.host}:${toString cfg.port}";
        PASEO_WEB_UI_ENABLED = "true";
        # Traefik serves the web UI from *.lab.nijho.lt; IPs and localhost are always allowed
        PASEO_HOSTNAMES = ".lab.nijho.lt";
        # Resolve the forwarded agent for each Git connection so SSH reconnects work.
        GIT_SSH_COMMAND = ''SSH_AUTH_SOCK="$(ls -t "$HOME"/.ssh/agent/s.*.sshd.* 2>/dev/null | head -n1)" ssh'';
      };
      # Without a password every client that reaches the port gets full control,
      # so wait until `paseo daemon set-password` has stored one.
      script = ''
        until ${pkgs.jq}/bin/jq -e .daemon.auth.password ${paseoHome}/config.json >/dev/null 2>&1; do
          echo "No daemon password in ${paseoHome}/config.json, run: paseo daemon set-password"
          sleep 60
        done
        exec ${bunBin}/paseo daemon run
      '';
      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        WorkingDirectory = homeDir;
      };
    };
  };
}
