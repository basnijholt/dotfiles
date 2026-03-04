{ config, pkgs, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain;
in
{
  # Runs locally and talks to Tuwunel over loopback.
  #
  # Telegram bridge requires API credentials from https://my.telegram.org/apps.
  # Startup is gated until non-placeholder credentials are present in the
  # environment file.
  services.mautrix-telegram = {
    enable = true;
    serviceDependencies = [ "tuwunel.service" ];
    environmentFile = config.age.secrets.telegram-appservice-env-mautrix.path;

    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = siteDomain;
      };

      appservice = {
        address = "http://127.0.0.1:29317";
        hostname = "127.0.0.1";
        port = 29317;
        id = "telegram";
        bot_username = "telegrambot";
        bot_displayname = "Telegram Bridge Bot";
        as_token = "$MAUTRIX_TELEGRAM_APPSERVICE_AS_TOKEN";
        hs_token = "$MAUTRIX_TELEGRAM_APPSERVICE_HS_TOKEN";
      };

      bridge = {
        command_prefix = "!tg";
        permissions = {
          "*" = "relaybot";
          "${siteDomain}" = "full";
          "@basnijholt:${siteDomain}" = "admin";
        };
      };
    };
  };

  systemd.services.mautrix-telegram.serviceConfig.ExecCondition = ''
    ${pkgs.bash}/bin/bash -lc '[ -n "''${MAUTRIX_TELEGRAM_TELEGRAM_API_ID:-}" ] \
      && [ "''${MAUTRIX_TELEGRAM_TELEGRAM_API_ID:-}" != "0" ] \
      && [ -n "''${MAUTRIX_TELEGRAM_TELEGRAM_API_HASH:-}" ] \
      && [ "''${MAUTRIX_TELEGRAM_TELEGRAM_API_HASH:-}" != "CHANGE_ME" ]'
  '';
}
