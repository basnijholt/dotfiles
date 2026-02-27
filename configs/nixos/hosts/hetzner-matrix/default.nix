# Hetzner Cloud VPS - MindRoom Tuwunel Matrix homeserver
#
# Public Matrix homeserver for MindRoom users. Users run MindRoom locally
# and connect to this server. Tuwunel is installed from GitHub releases
# on the host and reads /var/lib/tuwunel/tuwunel.toml.
#
# Also serves the MindRoom Cinny fork as the web client.
{ lib, pkgs, config, ... }:

let
  siteDomain = "mindroom.chat"; # Public website + Matrix API + Matrix well-known
  cinnyDomain = "chat.mindroom.chat"; # Web client domain
  tuwunelConfig = pkgs.writeText "tuwunel.toml" ''
    [global]
    server_name = "${siteDomain}"
    database_path = "/var/lib/tuwunel"
    address = ["127.0.0.1", "::1"]
    port = 8008
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
  '';
in
{
  imports = [
    ../../optional/zfs-auto-snapshot.nix
    ./networking.nix
  ];

  # ── Tuwunel Matrix homeserver ───────────────────────────────────────

  users.users.tuwunel = {
    isSystemUser = true;
    group = "tuwunel";
    home = "/var/lib/tuwunel";
  };
  users.groups.tuwunel = {};

  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets = {
    registration-token = {
      file = ./secrets/registration-token.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    sso-google-secret = {
      file = ./secrets/sso-google-secret.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    sso-github-secret = {
      file = ./secrets/sso-github-secret.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    sso-apple-secret = {
      file = ./secrets/sso-apple-secret.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/tuwunel 0750 tuwunel tuwunel -"
    "d /var/lib/tuwunel/bin 0755 tuwunel tuwunel -"
    "d /run/tuwunel 0755 tuwunel tuwunel -"
    "d /var/www/mindroom 0755 basnijholt users -"
    "d /var/www/cinny 0755 basnijholt users -"
  ];

  systemd.services.tuwunel = {
    description = "Tuwunel Matrix Homeserver (MindRoom fork)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "tuwunel";
      Group = "tuwunel";
      ExecStart = "/var/lib/tuwunel/bin/tuwunel.real";
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
      CONDUWUIT_CONFIG = tuwunelConfig;
      LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.liburing ];
    };
  };

  # ── Cinny web client ────────────────────────────────────────────────
  #
  # MindRoom Cinny fork served as static files by Caddy.
  # Build and deploy:
  #   ssh basnijholt@<server-ip>
  #   cd /var/www/cinny
  #   git clone https://github.com/mindroom-ai/mindroom-cinny .
  #   npm ci && npm run build
  #   # Caddy serves dist/ automatically

  # ── Caddy reverse proxy + web client ────────────────────────────────

  services.caddy = {
    enable = true;

    # Primary domain website + Matrix API + Matrix well-known
    virtualHosts."${siteDomain}" = {
      extraConfig = ''
        reverse_proxy /_matrix/* localhost:8008

        handle /.well-known/matrix/server {
          header Content-Type application/json
          respond 200 {
            body "{\"m.server\":\"${siteDomain}:443\"}"
            close
          }
        }

        handle /.well-known/matrix/client {
          header Content-Type application/json
          respond 200 {
            body "{\"m.homeserver\":{\"base_url\":\"https://${siteDomain}\"}}"
            close
          }
        }

        root * /var/www/mindroom
        try_files {path} /index.html
        file_server
      '';
    };

    # Cinny web client (SPA)
    virtualHosts."${cinnyDomain}" = {
      extraConfig = ''
        root * /var/www/cinny/dist
        try_files {path} /index.html
        file_server
      '';
    };
  };

  # ── General server config ──────────────────────────────────────────

  # Packages needed for Cinny builds and release-based Tuwunel updates.
  environment.systemPackages = with pkgs; [ nodejs git curl jq ];

  # Disable services not needed on a Matrix server
  services.fwupd.enable = lib.mkForce false;
  services.syncthing.enable = lib.mkForce false;

  # SSH config
  services.openssh.settings.UseDns = lib.mkForce false;
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # DNS (not on local LAN)
  networking.nameservers = lib.mkForce [ "1.1.1.1" "8.8.8.8" "100.100.100.100" ];

  # Nix caches (no local cache reachable)
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];

  # Limit build parallelism on small VPS
  nix.settings.max-jobs = 2;
  nix.settings.cores = 2;

  # Zram swap for builds
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # ZFS
  networking.hostId = "a1b2c3d4"; # Generate with: head -c4 /dev/urandom | od -A none -t x4 | tr -d ' '

  # Tailscale for management
  services.tailscale.enable = lib.mkForce true;
}
