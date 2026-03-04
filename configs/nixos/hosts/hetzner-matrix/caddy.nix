{ ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain cinnyDomain;
in
{
  systemd.tmpfiles.rules = [
    "d /var/www/mindroom 0755 basnijholt users -"
  ];

  services.caddy = {
    enable = true;

    # Primary domain website + Matrix API + Matrix well-known
    virtualHosts."${siteDomain}" = {
      extraConfig = ''
        reverse_proxy /_matrix/* localhost:8008
        reverse_proxy /v1/local-mindroom/* localhost:8776

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
}
