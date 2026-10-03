# T3 Code — web GUI harness for AI coding agents (Codex/Claude/OpenCode/PI).
# The CLI and provider binaries are managed outside Nix by scripts/sync-bun.sh.
# Mirrors configs/nixos/common/t3code.nix with a launchd agent instead of systemd.
{ config, lib, pkgs, ... }:

let
  cfg = config.local.t3code;
  homeDir = "/Users/${config.system.primaryUser}";
  bunBin = "${homeDir}/.bun/bin";
  logDir = "${homeDir}/Library/Logs/t3code";
in
{
  options.local.t3code = {
    enable = lib.mkEnableOption "the T3 Code user agent";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the T3 Code server listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3773;
      description = "TCP port on which the T3 Code server listens.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Runs in the GUI login session, so the agents can reach the login keychain
    launchd.user.agents.t3code = {
      script = ''
        ${lib.optionalString (cfg.host != "0.0.0.0") ''
          # Wait for the address (the tailnet IP while Tailscale is down) instead
          # of failing to bind and being restarted every few seconds
          until /sbin/ifconfig | grep -qF "inet ${cfg.host} "; do sleep 10; done
        ''}
        # s6-log rotates the log itself (1 MB, 3 old files). launchd's
        # StandardOutPath can't be rotated without restarting the server.
        # The pairing URL and token are printed to ~/Library/Logs/t3code/current.
        # exec keeps t3 as the job's process, so launchd restarts it when it dies.
        exec ${bunBin}/t3 serve --mode web --host ${cfg.host} --port ${toString cfg.port} --no-browser \
          > >(exec ${pkgs.s6}/bin/s6-log n3 s1000000 ${logDir}) 2>&1
      '';
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 5;
        WorkingDirectory = homeDir;
        EnvironmentVariables = {
          # node (for the t3 launcher and node-based providers) comes from Homebrew
          PATH = "${bunBin}:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          T3CODE_HOME = "${homeDir}/.t3";
        };
      };
    };
  };
}
