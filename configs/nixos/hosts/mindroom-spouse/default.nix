{
  config,
  lib,
  pkgs,
  ...
}:

let
  spouseDawarichEnvPath = config.age.secrets.spouse-dawarich-env.path;
in
{
  imports = [
    ../../optional/mindroom-companion.nix
    ./networking.nix
    ../../optional/openclaw/services.nix
  ];

  # Passwordless sudo for OpenClaw agent
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # signal-cli for OpenClaw Signal channel
  environment.systemPackages = [ pkgs.signal-cli ];

  nixpkgs.config.permittedInsecurePackages = lib.mkAfter [
    "openclaw-2026.6.11"
  ];

  age.secrets.spouse-dawarich-env = {
    file = ./secrets/spouse-dawarich.env.age;
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };

  # The shared agent-integrations-env no longer carries the main bot's telegram
  # token (PR #77), so the gateway picks up this container's own token from the
  # per-host agent-runtime-env. Do NOT UnsetEnvironment the token: openclaw
  # hard-fails at startup when it is missing.
  systemd.services.openclaw-gateway.serviceConfig.EnvironmentFile =
    lib.mkAfter [ spouseDawarichEnvPath ];
}
