{ lib, pkgs, config, ... }:
let
  constants = import ./constants.nix;
  inherit (constants) siteDomain tuwunelVersion tuwunelArchiveHash;

  tuwunelArchive = pkgs.fetchurl {
    url = "https://github.com/mindroom-ai/mindroom-tuwunel/releases/download/${tuwunelVersion}/tuwunel-${tuwunelVersion}-linux-x86_64.tar.gz";
    hash = tuwunelArchiveHash;
  };

  tuwunelPackage = pkgs.runCommand "tuwunel-${tuwunelVersion}-linux-x86_64" {
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
    allow_federation = false
    max_request_size = 25165824
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
    description = "Tuwunel Matrix Homeserver (MindRoom local)";
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
      ExecStart = "${tuwunelPackage}/bin/tuwunel";
      Restart = "on-failure";
      RestartSec = "5s";

      StateDirectory = "tuwunel";
      RuntimeDirectory = "tuwunel";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ "/var/lib/tuwunel" ];
      LimitNOFILE = 65536;
    };

    environment = {
      CONDUWUIT_CONFIG = "/run/tuwunel/tuwunel.toml";
      LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.liburing ];
    };
  };
}
