{
  lib,
  pkgs,
  ...
}:

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

  systemd.services.openclaw-gateway.serviceConfig.UnsetEnvironment = [
    "OPENCLAW_TELEGRAM_BOT_TOKEN"
    "TELEGRAM_BOT_TOKEN"
  ];
}
