{ pkgs, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain appDomain chatDomain pushDomain demoDomain demoTuwunelPort chatPublishedPath rtcJwtPort;
  pushkinSourceDir = pkgs.runCommandLocal "mindroom-pushkin-source" { } ''
    mkdir -p "$out"
    cp ${./mindroom_pushkin.py} "$out/mindroom_pushkin.py"
    cp ${./mindroom_pushkin_loader.py} "$out/mindroom_pushkin_loader.py"
  '';
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
        # More specific than the homeserver route; Caddy forwards websocket upgrades.
        reverse_proxy /_matrix/client/unstable/fi.mau.as_sync localhost:29331
        # Tuwunel serves MatrixRTC transport discovery, including CORS preflights.
        reverse_proxy /_matrix/* localhost:8008
        # Stylesheet and script of Tuwunel's SSO pages (UIA confirmation, sign-in).
        reverse_proxy /_tuwunel/sso/* localhost:8008
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
            body "{\"m.homeserver\":{\"base_url\":\"https://${siteDomain}\"},\"org.matrix.msc4143.rtc_foci\":[{\"type\":\"livekit\",\"livekit_service_url\":\"https://${siteDomain}/livekit/jwt\"}],\"io.mindroom.bug_reports\":{\"admins\":[\"@basnijholt:${siteDomain}\"]}}"
            close
          }
        }

        # MatrixRTC (Element Call) backend, path-routed to avoid extra DNS records.
        handle_path /livekit/jwt/* {
          reverse_proxy localhost:${toString rtcJwtPort}
        }
        handle_path /livekit/sfu/* {
          reverse_proxy localhost:7880
        }

        handle / {
          redir https://${appDomain}/ 308
        }

        root * /var/www/mindroom
        # Keep the website's SPA fallback from rewriting API/discovery requests.
        @siteFiles {
          not path /_matrix/* /_tuwunel/sso/* /v1/local-mindroom/* /.well-known/matrix/* /livekit/* /
          file {path} /index.html
        }
        rewrite @siteFiles {file_match.relative}
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

    # MindRoom Chat static build, published by the dev repo's
    # scripts/mindroom-chat-publish.py into releases/; `current` is the live one.
    virtualHosts."${chatDomain}" = {
      extraConfig = import ../../optional/mindroom-chat-caddy.nix {
        root = "${chatPublishedPath}/current";
      };
    };

    # Matrix push gateway for native mobile clients.
    virtualHosts."${pushDomain}" = {
      extraConfig = ''
        # AGPL-3.0 section 13 source offer for Sygnal v0.17.0 + MindroomApnsPushkin.
        @sourceOffer {
          method GET HEAD
          path /
        }
        handle @sourceOffer {
          header Content-Type "text/plain; charset=utf-8"
          respond 200 {
            body <<EOF
            MindRoom Matrix push gateway (Sygnal v0.17.0, AGPL-3.0, with MindroomApnsPushkin).
            Corresponding source:
            - Sygnal v0.17.0: https://github.com/element-hq/sygnal/tree/v0.17.0
            - MindroomApnsPushkin: https://${pushDomain}/mindroom_pushkin.py
            - Loader: https://${pushDomain}/mindroom_pushkin_loader.py
            EOF
          }
        }

        @pushkinSource {
          method GET HEAD
          path /mindroom_pushkin.py /mindroom_pushkin_loader.py
        }
        handle @pushkinSource {
          root * ${pushkinSourceDir}
          header Content-Type "text/plain; charset=utf-8"
          file_server
        }

        handle {
          reverse_proxy localhost:5000
        }
      '';
    };
  };
}
