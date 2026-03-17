{ ... }:
let
  constants = import ./constants.nix;
  inherit (constants)
    siteDomain
    publicSiteDomain
    publicCinnyDomain
    publicElementDomain
    ;
in
{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "${publicSiteDomain}:80" = {
        extraConfig = ''
          reverse_proxy /_matrix/* 127.0.0.1:8008
          reverse_proxy /v1/local-mindroom/* 127.0.0.1:8766

          handle /.well-known/matrix/server {
            header Content-Type application/json
            respond 200 {
              body "{\"m.server\":\"${publicSiteDomain}:443\"}"
              close
            }
          }

          handle /.well-known/matrix/client {
            header Content-Type application/json
            respond 200 {
              body "{\"m.homeserver\":{\"base_url\":\"https://${publicSiteDomain}\"}}"
              close
            }
          }

          reverse_proxy 127.0.0.1:8766
        '';
      };

      "${publicCinnyDomain}:80" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8090
        '';
      };

      "${publicElementDomain}:80" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8091
        '';
      };
    };
  };
}
