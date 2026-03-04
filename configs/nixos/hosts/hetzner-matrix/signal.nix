{ config, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain;
in
{
  # Runs locally and talks to Tuwunel over loopback.
  # Appservice registration still needs one-time admin registration in Tuwunel
  # using /var/lib/mautrix-signal/signal-registration.yaml.
  services.mautrix-signal = {
    enable = true;
    serviceDependencies = [ "tuwunel.service" ];
    environmentFile = config.age.secrets.signal-appservice-env-mautrix.path;

    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = siteDomain;
      };

      appservice = {
        hostname = "127.0.0.1";
        port = 29328;
        id = "signal";
        as_token = "$MAUTRIX_SIGNAL_AS_TOKEN";
        hs_token = "$MAUTRIX_SIGNAL_HS_TOKEN";
        bot = {
          username = "signalbot";
          displayname = "Signal Bridge Bot";
        };
      };

      database.type = "sqlite3-fk-wal";

      bridge = {
        command_prefix = "!signal";
        permissions = {
          "*" = "relay";
          "${siteDomain}" = "user";
          "@basnijholt:${siteDomain}" = "admin";
        };
      };

      encryption = {
        allow = true;
        default = false;
        require = false;
        pickle_key = "$MAUTRIX_SIGNAL_ENCRYPTION_PICKLE_KEY";
      };

      logging.min_level = "info";
    };
  };
}
