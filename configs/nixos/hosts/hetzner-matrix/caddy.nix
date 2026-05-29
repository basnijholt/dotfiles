{ ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain appDomain cinnyDomain pushDomain demoDomain demoTuwunelPort cinnyCurrentPath;
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
          header Access-Control-Allow-Origin "*"
          respond 200 {
            body "{\"m.server\":\"${siteDomain}:443\"}"
            close
          }
        }

        handle /.well-known/matrix/client {
          header Content-Type application/json
          header Access-Control-Allow-Origin "*"
          respond 200 {
            body "{\"m.homeserver\":{\"base_url\":\"https://${siteDomain}\"}}"
            close
          }
        }

        handle / {
          redir https://${appDomain}/ 308
        }

        root * /var/www/mindroom
        try_files {path} /index.html
        file_server
      '';
    };

    # Demo Matrix homeserver for TestFlight/App Review password-only testing.
    virtualHosts."${demoDomain}" = {
      extraConfig = ''
        @demoRegistration path /_matrix/client/r0/register* /_matrix/client/v3/register* /_matrix/client/unstable/register*
        respond @demoRegistration 403

        reverse_proxy /_matrix/* localhost:${toString demoTuwunelPort}

        handle /.well-known/matrix/server {
          header Content-Type application/json
          header Access-Control-Allow-Origin "*"
          respond 200 {
            body "{\"m.server\":\"${demoDomain}:443\"}"
            close
          }
        }

        handle /.well-known/matrix/client {
          header Content-Type application/json
          header Access-Control-Allow-Origin "*"
          respond 200 {
            body "{\"m.homeserver\":{\"base_url\":\"https://${demoDomain}\"}}"
            close
          }
        }

        @demoRoot path /
        respond @demoRoot 200 {
          body "MindRoom demo Matrix homeserver"
        }
      '';
    };

    # Cinny web client (SPA)
    virtualHosts."${cinnyDomain}" = {
      extraConfig = ''
        root * ${cinnyCurrentPath}
        try_files {path} /index.html
        file_server
      '';
    };

    # Matrix push gateway for native mobile clients.
    virtualHosts."${pushDomain}" = {
      extraConfig = ''
        reverse_proxy localhost:5000
      '';
    };
  };
}
