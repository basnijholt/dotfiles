# Hetzner Cloud VPS - MindRoom Tuwunel Matrix homeserver
#
# Public Matrix homeserver for MindRoom users. Users run MindRoom locally
# and connect to this server. Tuwunel is the MindRoom fork with edit
# compaction and purge features for streaming AI responses.
#
# Also serves the MindRoom Cinny fork as the web client.
{ lib, pkgs, config, ... }:

let
  domain = "matrix.mindroom.chat"; # Cannot change after first run!
  cinnyDomain = "chat.mindroom.chat"; # Web client domain

  tuwunelConfig = pkgs.writeText "tuwunel.toml" ''
    [global]
    server_name = "${domain}"
    database_path = "/var/lib/tuwunel"

    # Listen only on localhost (Caddy handles TLS + public traffic)
    address = ["127.0.0.1", "::1"]
    port = 8008

    # Registration: require a token OR SSO (Google/Apple/GitHub)
    # Token is read from a file on the server, not stored in the repo.
    # Create it with: echo "your-secret-token" > /var/lib/tuwunel/registration-token
    allow_registration = true
    registration_token_file = "/var/lib/tuwunel/registration-token"

    # Federation: let users interact with other Matrix servers
    allow_federation = true

    # MindRoom fork: collapse superseded m.replace events in /sync responses
    # This dramatically reduces bandwidth for MindRoom's streaming edits
    mindroom_compact_edits_enabled = true

    # MindRoom fork: background purge of old superseded edit events
    mindroom_edit_purge_enabled = true
    mindroom_edit_purge_min_age_secs = 86400
    mindroom_edit_purge_interval_secs = 3600
    mindroom_edit_purge_batch_size = 1000

    # Upload limit (24 MiB default)
    max_request_size = 25165824

    # Well-known delegation: federation uses port 443 (no need for 8448)
    [global.well_known]
    client = "https://${domain}"
    server = "${domain}:443"

    # ── SSO: Google ───────────────────────────────────────────────────
    # 1. Create OAuth app: https://console.cloud.google.com/apis/credentials
    # 2. Set callback URL to: https://${domain}/_matrix/client/unstable/login/sso/callback/<client_id>
    # 3. Put client_id below, put client_secret in /var/lib/tuwunel/sso-google-secret

    [[global.identity_provider]]
    brand = "Google"
    client_id = "CHANGEME"
    client_secret_file = "/var/lib/tuwunel/sso-google-secret"
    callback_url = "https://${domain}/_matrix/client/unstable/login/sso/callback/CHANGEME"
    default = true

    # ── SSO: GitHub ───────────────────────────────────────────────────
    # 1. Create OAuth app: https://github.com/settings/developers
    # 2. Set callback URL to: https://${domain}/_matrix/client/unstable/login/sso/callback/<client_id>
    # 3. Put client_id below, put client_secret in /var/lib/tuwunel/sso-github-secret

    [[global.identity_provider]]
    brand = "GitHub"
    client_id = "CHANGEME"
    client_secret_file = "/var/lib/tuwunel/sso-github-secret"
    callback_url = "https://${domain}/_matrix/client/unstable/login/sso/callback/CHANGEME"

    # ── SSO: Apple ────────────────────────────────────────────────────
    # 1. Create Service ID: https://developer.apple.com/account/resources/identifiers/list/serviceId
    # 2. Set callback URL to: https://${domain}/_matrix/client/unstable/login/sso/callback/<client_id>
    # 3. Put client_id (Service ID) below, put client_secret in /var/lib/tuwunel/sso-apple-secret

    [[global.identity_provider]]
    brand = "Apple"
    client_id = "CHANGEME"
    client_secret_file = "/var/lib/tuwunel/sso-apple-secret"
    callback_url = "https://${domain}/_matrix/client/unstable/login/sso/callback/CHANGEME"
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

  systemd.tmpfiles.rules = [
    "d /var/lib/tuwunel 0750 tuwunel tuwunel -"
    "d /run/tuwunel 0755 tuwunel tuwunel -"
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
      ExecStart = "${pkgs.matrix-tuwunel}/bin/tuwunel";
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
      CONDUWUIT_CONFIG = "${tuwunelConfig}";
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

    # Matrix homeserver API
    virtualHosts."${domain}" = {
      extraConfig = ''
        reverse_proxy /_matrix/* localhost:8008
        reverse_proxy /.well-known/matrix/* localhost:8008

        respond / 200 {
          body "MindRoom Matrix Server"
          close
        }
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

  # Packages needed for building Cinny on the server
  environment.systemPackages = with pkgs; [ nodejs git ];

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
