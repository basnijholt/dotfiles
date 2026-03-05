{ lib, config, ... }:
let
  constants = import ./constants.nix;
  inherit (constants)
    siteDomain
    publicBaseDomain
    publicSiteDomain
    publicCinnyDomain
    publicElementDomain
    ;

  hasCloudflareAcmeSecret = config.age.secrets ? cloudflare-acme-env;
  vhostName = host: if hasCloudflareAcmeSecret then host else "${host}:80";
  withOptionalAcme = cfg:
    cfg
    // lib.optionalAttrs hasCloudflareAcmeSecret {
      useACMEHost = publicBaseDomain;
    };
in
{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "${vhostName publicSiteDomain}" = withOptionalAcme {
        extraConfig = ''
          reverse_proxy /_matrix/* 127.0.0.1:8008
          reverse_proxy /v1/local-mindroom/* 127.0.0.1:8766

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

          reverse_proxy 127.0.0.1:8766
        '';
      };

      "${vhostName publicCinnyDomain}" = withOptionalAcme {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8090
        '';
      };

      "${vhostName publicElementDomain}" = withOptionalAcme {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8091
        '';
      };
    };
  };

  security.acme = lib.mkIf hasCloudflareAcmeSecret {
    acceptTerms = true;
    defaults.email = "bas@nijho.lt";
    certs."${publicBaseDomain}" = {
      domain = publicBaseDomain;
      extraDomainNames = [ "*.${publicBaseDomain}" ];
      dnsProvider = "cloudflare";
      credentialsFile = config.age.secrets.cloudflare-acme-env.path;
      group = "caddy";
      reloadServices = [ "caddy.service" ];
    };
  };
}
