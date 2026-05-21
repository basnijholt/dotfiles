{ lib, pkgs, config, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) demoDomain demoTuwunelPort tuwunelVersion tuwunelArchiveHash;

  tuwunelArchive = pkgs.fetchurl {
    url = "https://github.com/mindroom-ai/mindroom-tuwunel/releases/download/${tuwunelVersion}/tuwunel-${tuwunelVersion}-linux-aarch64.tar.gz";
    hash = tuwunelArchiveHash;
  };

  tuwunelPackage = pkgs.runCommand "tuwunel-demo-${tuwunelVersion}-linux-aarch64" {
    nativeBuildInputs = with pkgs; [ gnutar gzip findutils ];
  } ''
    mkdir -p "$out/bin"
    tar -xzf "${tuwunelArchive}" -C "$TMPDIR"
    bin_path="$(find "$TMPDIR" -maxdepth 2 -type f -name tuwunel | head -n1)"
    install -m 0755 "$bin_path" "$out/bin/tuwunel"
  '';

  tuwunelDemoHealthcheck = pkgs.writeShellScript "tuwunel-demo-healthcheck" ''
    set -euo pipefail

    check() {
      ${pkgs.curl}/bin/curl \
        --fail \
        --silent \
        --show-error \
        --max-time 10 \
        --output /dev/null \
        http://127.0.0.1:${toString demoTuwunelPort}/_matrix/client/versions
    }

    for _ in 1 2; do
      if check; then
        exit 0
      fi
      sleep 5
    done

    echo "Tuwunel demo healthcheck failed twice; restarting tuwunel-demo.service" >&2
    ${pkgs.systemd}/bin/systemctl restart tuwunel-demo.service
  '';

  tuwunelDemoConfig = pkgs.writeText "tuwunel-demo.toml" ''
    [global]
    server_name = "${demoDomain}"
    database_path = "/var/lib/tuwunel-demo"
    address = ["127.0.0.1", "::1"]
    port = ${toString demoTuwunelPort}
    # Caddy blocks public registration endpoints; the token keeps local
    # operator-created review accounts explicit instead of open-registration.
    allow_registration = true
    grant_admin_to_first_user = false
    registration_token_file = "${config.age.secrets.registration-token-demo.path}"
    allow_federation = false
    mindroom_compact_edits_enabled = true
    mindroom_edit_purge_enabled = true
    mindroom_edit_purge_min_age_secs = 86400
    mindroom_edit_purge_interval_secs = 3600
    mindroom_edit_purge_batch_size = 10000
    max_request_size = 25165824

    [global.well_known]
    client = "https://${demoDomain}"
    server = "${demoDomain}:443"
  '';
in
{
  users.users.tuwunel-demo = {
    isSystemUser = true;
    group = "tuwunel-demo";
    home = "/var/lib/tuwunel-demo";
  };
  users.groups.tuwunel-demo = { };

  systemd.tmpfiles.rules = [
    "d /var/lib/tuwunel-demo 0750 tuwunel-demo tuwunel-demo -"
    "d /run/tuwunel-demo 0755 tuwunel-demo tuwunel-demo -"
  ];

  systemd.services.tuwunel-demo = {
    description = "Tuwunel Demo Matrix Homeserver (MindRoom fork)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      cp ${tuwunelDemoConfig} /run/tuwunel-demo/tuwunel.toml
    '';

    serviceConfig = {
      Type = "simple";
      User = "tuwunel-demo";
      Group = "tuwunel-demo";
      ExecStart = "${tuwunelPackage}/bin/tuwunel";
      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening
      StateDirectory = "tuwunel-demo";
      RuntimeDirectory = "tuwunel-demo";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ "/var/lib/tuwunel-demo" ];

      # Limits
      LimitNOFILE = 65536;
    };

    environment = {
      CONDUWUIT_CONFIG = "/run/tuwunel-demo/tuwunel.toml";
      LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.liburing ];
    };
  };

  systemd.services.tuwunel-demo-healthcheck = {
    description = "Restart Tuwunel demo when the Matrix client endpoint hangs";
    after = [ "network-online.target" "tuwunel-demo.service" ];
    wants = [ "network-online.target" "tuwunel-demo.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${tuwunelDemoHealthcheck}";
    };
  };

  systemd.timers.tuwunel-demo-healthcheck = {
    description = "Run Tuwunel demo HTTP healthcheck";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
      AccuracySec = "10s";
      Unit = "tuwunel-demo-healthcheck.service";
    };
  };
}
