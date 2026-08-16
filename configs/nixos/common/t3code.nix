# T3 Code — web GUI harness for AI coding agents (Codex/Claude/OpenCode/PI).
# The CLI and provider binaries are managed outside Nix by scripts/sync-bun.sh.
{ config, lib, ... }:

let
  cfg = config.local.t3code;
  homeDir = config.users.users.basnijholt.home;
  bunBin = "${homeDir}/.bun/bin";
  systemBin = "/run/current-system/sw/bin";
in
{
  options.local.t3code = {
    enable = lib.mkEnableOption "the T3 Code user service";

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
    systemd.user.services.t3code = {
      enable = true;
      description = "T3 Code server (AI coding agent web GUI)";
      wantedBy = [ "default.target" ];
      environment = {
        PATH = lib.mkForce "${bunBin}:${systemBin}";
        T3CODE_HOME = "${homeDir}/.t3";
      };
      serviceConfig = {
        ExecStart = "${bunBin}/t3 serve --mode web --host ${cfg.host} --port ${toString cfg.port} --no-browser";
        Restart = "always";
        RestartSec = 5;
        WorkingDirectory = homeDir;
      };
    };
  };
}
