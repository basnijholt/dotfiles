# Paseo — daemon and web UI for running AI coding agents (Claude/Codex/OpenCode) from any device.
# The CLI is managed outside Nix by scripts/sync-bun.sh.
# Mirrors configs/nixos/common/paseo.nix with a launchd agent instead of systemd.
{ config, lib, pkgs, ... }:

let
  cfg = config.local.paseo;
  homeDir = "/Users/${config.system.primaryUser}";
  bunBin = "${homeDir}/.bun/bin";
  paseoHome = "${homeDir}/.paseo";
  logDir = "${homeDir}/Library/Logs/paseo";
in
{
  options.local.paseo = {
    enable = lib.mkEnableOption "the Paseo daemon user agent";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the Paseo daemon listens.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The application firewall holds incoming connections to Homebrew's ad-hoc
    # signed node, which runs the daemon, for a prompt nobody answers on a
    # headless Mac. It tracks the binary by hash, so allow it again after every
    # Homebrew upgrade. This allows any server run by this node, not just Paseo.
    system.activationScripts.postActivation.text = ''
      if node=$(/usr/bin/readlink -f /opt/homebrew/bin/node); then
        /usr/libexec/ApplicationFirewall/socketfilterfw --add "$node" >&2 || true
        /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$node" >&2 || true
      fi
    '';

    # Runs in the GUI login session, so the agents can reach the login keychain
    launchd.user.agents.paseo = {
      script = ''
        # s6-log rotates the log itself (1 MB, 3 old files). launchd's
        # StandardOutPath can't be rotated without restarting the daemon.
        exec > >(exec ${pkgs.s6}/bin/s6-log n3 s1000000 ${logDir}) 2>&1
        ${lib.optionalString (cfg.host != "0.0.0.0") ''
          # Wait for the address (the tailnet IP while Tailscale is down) instead
          # of failing to bind and being restarted every few seconds
          until /sbin/ifconfig | grep -qF "inet ${cfg.host} "; do sleep 10; done
        ''}
        # Without a password every client that reaches the port gets full
        # control, so wait until `paseo daemon set-password` has stored one.
        until ${pkgs.jq}/bin/jq -e .daemon.auth.password ${paseoHome}/config.json >/dev/null 2>&1; do
          echo "No daemon password in ${paseoHome}/config.json, run: paseo daemon set-password"
          sleep 60
        done
        # exec keeps paseo as the job's process, so launchd restarts it when it dies.
        exec ${bunBin}/paseo daemon run
      '';
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 5;
        WorkingDirectory = homeDir;
        EnvironmentVariables = {
          # node (for the paseo launcher and node-based providers) comes from Homebrew
          PATH = "${bunBin}:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          PASEO_LISTEN = "${cfg.host}:6767";
          PASEO_WEB_UI_ENABLED = "true";
          # Traefik serves the web UI from *.lab.nijho.lt; IPs and localhost are always allowed
          PASEO_HOSTNAMES = ".lab.nijho.lt";
        };
      };
    };
  };
}
