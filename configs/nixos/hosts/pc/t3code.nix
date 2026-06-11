# T3 Code — Theo's web GUI harness for AI coding agents (Codex/Claude/OpenCode/PI).
# Runs as the user so it can read provider auth (~/.codex, ~/.claude, etc.) and the
# bun-global CLIs in ~/.bun/bin. The `t3` binary itself is installed via
# scripts/sync-bun.sh (bun install -g t3@latest), NOT by Nix, so ~/.bun/bin must be
# on PATH for both `t3` and the provider CLIs it shells out to.
# Exposed at https://t3.lab.nijho.lt via Traefik on docker-lxc (manual.yml route).
{ config, lib, ... }:

let
  homeDir = config.users.users.basnijholt.home;
  bunBin = "${homeDir}/.bun/bin";
  # Keep ~/.bun/bin first for t3 and provider CLIs, then use the active NixOS
  # generation's system profile so the unit does not pin per-package store paths.
  systemBin = "/run/current-system/sw/bin";
in
{
  systemd.user.services."t3code" = {
    enable = true;
    description = "T3 Code server (AI coding agent web GUI)";
    wantedBy = [ "default.target" ];
    # Use the default T3CODE_HOME (~/.t3) so interactive `t3 auth ...` writes to the
    # same DB the server reads — avoids "Invalid pairing token" from a base-dir mismatch.
    environment = {
      PATH = lib.mkForce "${bunBin}:${systemBin}";
      T3CODE_HOME = "${homeDir}/.t3";
    };
    serviceConfig = {
      ExecStart = "${bunBin}/t3 serve --mode web --host 0.0.0.0 --port 3773 --no-browser";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = homeDir;
    };
  };
}
