{ ... }:
let
  constants = import ./constants.nix;
  inherit (constants)
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
          # The lab host fronts the app UI; Matrix discovery and the canonical
          # homeserver for the public clients currently live elsewhere.
          route {
            handle /.well-known/matrix/* {
              respond "Not found" 404
            }

            handle /_matrix/* {
              respond "Not found" 404
            }

            handle /v1/local-mindroom/* {
              reverse_proxy 127.0.0.1:8766
            }

            handle {
              reverse_proxy 127.0.0.1:8766
            }
          }
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
