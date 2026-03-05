{ lib, pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: mindroom is a lightweight development container
    ../../optional/git-repo-checkouts.nix
    ../../optional/virtualization.nix
    ../../optional/mindroom-runtime-services.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./secrets-config.nix
    ./mindroom.nix
    ./cinny.nix
    ./element.nix
    ./tuwunel.nix  # Local Matrix homeserver (MindRoom Tuwunel fork)
    ./caddy.nix
    (import ../../optional/openclaw-gateway.nix {
      gatewayTokenEnv = "MINDROOM_GATEWAY_TOKEN";
      telegramBotTokenEnv = "OPENCLAW_TELEGRAM_BOT_TOKEN";
      llmProxyApiKeyEnv = "OPENCLAW_LLM_PROXY_API_KEY";
      signalAccountEnv = "OPENCLAW_SIGNAL_ACCOUNT";
    })
  ];

  # Allow basnijholt passwordless sudo (for mindroom agent)
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # signal-cli for OpenClaw Signal channel
  environment.systemPackages = [ pkgs.signal-cli ];

  # OpenClaw and related runtime services are managed as NixOS system services.

  # Disable comin on this host — we deploy manually via nixos-rebuild switch.
  services.comin.enable = lib.mkForce false;
}
