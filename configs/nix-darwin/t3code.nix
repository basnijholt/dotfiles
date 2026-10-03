# T3 Code — web GUI harness for AI coding agents (Codex/Claude/OpenCode/PI).
# The CLI and provider binaries are managed outside Nix by scripts/sync-bun.sh.
# Mirrors configs/nixos/common/t3code.nix with a launchd agent instead of systemd.
{ config, lib, ... }:

let
  cfg = config.local.t3code;
  homeDir = "/Users/${config.system.primaryUser}";
  bunBin = "${homeDir}/.bun/bin";
  logFile = "${homeDir}/Library/Logs/t3code.log";
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
      command = "${bunBin}/t3 serve --mode web --host ${cfg.host} --port ${toString cfg.port} --no-browser";
      serviceConfig = {
        RunAtLoad = true;
        # Also retries until Tailscale is up when binding to the tailnet IP
        KeepAlive = true;
        ThrottleInterval = 5;
        WorkingDirectory = homeDir;
        # The pairing URL and token are printed here on startup
        StandardOutPath = logFile;
        StandardErrorPath = logFile;
        EnvironmentVariables = {
          # node (for the t3 launcher and node-based providers) comes from Homebrew
          PATH = "${bunBin}:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          T3CODE_HOME = "${homeDir}/.t3";
        };
      };
    };

    # While the tailnet IP is down, every KeepAlive retry appends a bind error,
    # so cap the log: rotate at 1 MiB, keep 3 old copies.
    environment.etc."newsyslog.d/t3code.conf".text = ''
      ${logFile} ${config.system.primaryUser}:staff 644 3 1024 * N
    '';
  };
}
