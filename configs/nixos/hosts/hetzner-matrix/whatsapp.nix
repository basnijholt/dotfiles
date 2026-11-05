{ config, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain;
in
{
  # Runs locally and talks to Tuwunel over loopback.
  services.mautrix-whatsapp = {
    enable = true;
    serviceDependencies = [ "tuwunel.service" ];
    environmentFile = config.age.secrets.whatsapp-appservice-env-mautrix.path;

    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = siteDomain;
      };

      appservice = {
        hostname = "127.0.0.1";
        port = 29318;
        id = "whatsapp";
        as_token = "$MAUTRIX_WHATSAPP_AS_TOKEN";
        hs_token = "$MAUTRIX_WHATSAPP_HS_TOKEN";
        bot = {
          username = "whatsappbot";
          displayname = "WhatsApp Bridge Bot";
        };
        username_template = "whatsapp_{{.}}";
      };

      # Prefer the name saved in the logged-in user's phone contacts. The
      # upstream default leaves it out, so every contact without a WhatsApp
      # profile name shows up as a phone number. Ghosts are shared between
      # logins, so another bridge user can see that saved name too.
      network.displayname_template = "{{or .FullName .BusinessName .PushName .Phone}} (WA)";

      bridge = {
        command_prefix = "!wa";
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
        pickle_key = "$MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY";
      };

      logging.min_level = "info";
    };
  };
}
