# Hetzner Cloud VPS - MindRoom Tuwunel Matrix homeserver
#
# Public Matrix homeserver for MindRoom users. Users run MindRoom locally
# and connect to this server. Tuwunel is installed from GitHub releases
# on the host and reads /var/lib/tuwunel/tuwunel.toml.
#
# Also serves the MindRoom Cinny fork as the web client.
{ lib, pkgs, ... }:

let
  domain = "matrix.mindroom.chat"; # Cannot change after first run!
  cinnyDomain = "chat.mindroom.chat"; # Web client domain
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
    "d /var/lib/tuwunel/bin 0755 tuwunel tuwunel -"
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
      CONDUWUIT_CONFIG = "/var/lib/tuwunel/tuwunel.toml";
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
