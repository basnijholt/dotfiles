{ lib, pkgs, ... }:

{
  imports = [
    ./networking.nix
    (import ../../optional/openclaw-gateway.nix {
      gatewayTokenEnv = "SPOUSE_GATEWAY_TOKEN";
      telegramBotTokenEnv = "SPOUSE_TELEGRAM_BOT_TOKEN";
      llmProxyApiKeyEnv = "SPOUSE_LLM_PROXY_API_KEY";
      signalAccountEnv = "SPOUSE_SIGNAL_ACCOUNT";
    })
  ];

  # Passwordless sudo for OpenClaw agent
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # signal-cli for OpenClaw Signal channel
  environment.systemPackages = [ pkgs.signal-cli ];

  # OpenClaw is managed as a NixOS system service.
}
