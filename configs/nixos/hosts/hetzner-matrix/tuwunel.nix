{ lib, pkgs, config, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain tuwunelVersion tuwunelArchiveHash;

  tuwunelArchive = pkgs.fetchurl {
    url = "https://github.com/mindroom-ai/mindroom-tuwunel/releases/download/${tuwunelVersion}/tuwunel-${tuwunelVersion}-linux-aarch64.tar.gz";
    hash = tuwunelArchiveHash;
  };

  tuwunelPackage = pkgs.runCommand "tuwunel-${tuwunelVersion}-linux-aarch64" {
    nativeBuildInputs = with pkgs; [ gnutar gzip findutils ];
  } ''
    mkdir -p "$out/bin"
    tar -xzf "${tuwunelArchive}" -C "$TMPDIR"
    bin_path="$(find "$TMPDIR" -maxdepth 2 -type f -name tuwunel | head -n1)"
    install -m 0755 "$bin_path" "$out/bin/tuwunel"
  '';

  tuwunelConfigTemplate = pkgs.writeText "tuwunel.toml" ''
    [global]
    server_name = "${siteDomain}"
    database_path = "/var/lib/tuwunel"
    address = ["127.0.0.1", "::1"]
    port = 8008
    # Token-gated registration; token is loaded from an agenix-managed secret file.
    allow_registration = true
    registration_token_file = "${config.age.secrets.registration-token.path}"
    allow_federation = true
    mindroom_compact_edits_enabled = true
    mindroom_edit_purge_enabled = true
    mindroom_edit_purge_min_age_secs = 86400
    mindroom_edit_purge_interval_secs = 3600
    mindroom_edit_purge_batch_size = 1000
    max_request_size = 25165824

    [global.well_known]
    client = "https://${siteDomain}"
    server = "${siteDomain}:443"

    [[global.identity_provider]]
    brand = "Google"
    client_id = "974295579207-8d3ippmssoiaibuu04id02sb66rgi1h3.apps.googleusercontent.com"
    client_secret_file = "${config.age.secrets.sso-google-secret.path}"
    callback_url = "https://${siteDomain}/_matrix/client/unstable/login/sso/callback/974295579207-8d3ippmssoiaibuu04id02sb66rgi1h3.apps.googleusercontent.com"
    default = true

    [[global.identity_provider]]
    brand = "GitHub"
    client_id = "Ov23li6wDSuBsiVjYWar"
    client_secret_file = "${config.age.secrets.sso-github-secret.path}"
    callback_url = "https://${siteDomain}/_matrix/client/unstable/login/sso/callback/Ov23li6wDSuBsiVjYWar"

    [[global.identity_provider]]
    brand = "AppleOIDC"
    name = "Apple"
    client_id = "chat.mindroom.matrix.apple"
    client_secret_file = "${config.age.secrets.sso-apple-secret.path}"
    issuer_url = "https://appleid.apple.com"
    callback_url = "https://${siteDomain}/_matrix/client/unstable/login/sso/callback/chat.mindroom.matrix.apple"
    scope = ["openid"]

    [global.appservice.signal]
    url = "http://localhost:29328"
    as_token = "$TUWUNEL_SIGNAL_AS_TOKEN"
    hs_token = "$TUWUNEL_SIGNAL_HS_TOKEN"
    sender_localpart = "signalbot"
    rate_limited = false
    receive_ephemeral = true

    [[global.appservice.signal.users]]
    regex = "^@signalbot:mindroom\\.chat$"
    exclusive = true

    [[global.appservice.signal.users]]
    regex = "^@signal_.*:mindroom\\.chat$"
    exclusive = true

    [global.appservice.whatsapp]
    url = "http://localhost:29318"
    as_token = "$TUWUNEL_WHATSAPP_AS_TOKEN"
    hs_token = "$TUWUNEL_WHATSAPP_HS_TOKEN"
    sender_localpart = "whatsappbot"
    rate_limited = false
    receive_ephemeral = true

    [[global.appservice.whatsapp.users]]
    regex = "^@whatsappbot:mindroom\\.chat$"
    exclusive = true

    [[global.appservice.whatsapp.users]]
    regex = "^@whatsapp_.*:mindroom\\.chat$"
    exclusive = true
  '';
in
{
  users.users.tuwunel = {
    isSystemUser = true;
    group = "tuwunel";
    home = "/var/lib/tuwunel";
  };
  users.groups.tuwunel = { };

  systemd.tmpfiles.rules = [
    "d /var/lib/tuwunel 0750 tuwunel tuwunel -"
    "d /run/tuwunel 0755 tuwunel tuwunel -"
  ];

  systemd.services.tuwunel = {
    description = "Tuwunel Matrix Homeserver (MindRoom fork)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      ${pkgs.envsubst}/bin/envsubst \
        -o /run/tuwunel/tuwunel.toml \
        -i ${tuwunelConfigTemplate}
    '';

    serviceConfig = {
      Type = "simple";
      User = "tuwunel";
      Group = "tuwunel";
      EnvironmentFile = [
        config.age.secrets.signal-appservice-env-tuwunel.path
        config.age.secrets.whatsapp-appservice-env-tuwunel.path
      ];
      ExecStart = "${tuwunelPackage}/bin/tuwunel";
      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening
      StateDirectory = "tuwunel";
      RuntimeDirectory = "tuwunel";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ "/var/lib/tuwunel" ];

      # Limits
      LimitNOFILE = 65536;
    };

    environment = {
      CONDUWUIT_CONFIG = "/run/tuwunel/tuwunel.toml";
      LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.liburing ];
    };
  };
}
