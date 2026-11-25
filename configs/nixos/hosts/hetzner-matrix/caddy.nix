{ config, mindroom-sygnal, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain appDomain chatDomain pushDomain demoDomain demoTuwunelPort chatPublishedPath rtcJwtPort;

  # Never persist legacy ?access_token= query params into Caddy access logs.
  redactedAccessLogFormat = host: ''
    output file ${config.services.caddy.logDir}/access-${host}.log
    format filter {
      fields {
        request>uri query {
          delete access_token
        }
      }
    }
  '';

  # Temporary MSC4127 compatibility shim (remove after 2026-12-25):
  # Capacitor native apps older than mindroom-chat v2026.11.414 (including live App Store
  # 2026.11.404 and mindroom-chat-legacy) send ?access_token= on authenticated media GET/HEAD
  # requests instead of Authorization: Bearer. Promote a single valid query token to a Bearer
  # header before stripping it from the upstream query string.
  legacyMediaQueryTokenShim = upstream: ''
    @legacyMediaQueryToken {
      method GET HEAD
      path /_matrix/client/v1/media/download/* /_matrix/client/v1/media/thumbnail/*
      not header Authorization *
      expression `{http.request.uri.query.access_token}.matches("^[A-Za-z0-9._~+/=-]+$") && !{http.request.uri.query}.matches("(^|&)access_token(=|&|$).*&access_token(=|&|$)")`
    }
    handle @legacyMediaQueryToken {
      route {
        request_header Authorization "Bearer {http.request.uri.query.access_token}"
        uri query -access_token
        reverse_proxy ${upstream}
      }
    }
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
      logFormat = redactedAccessLogFormat siteDomain;
      extraConfig = ''
        # More specific than the homeserver route; Caddy forwards websocket upgrades.
        reverse_proxy /_matrix/client/unstable/fi.mau.as_sync localhost:29331
        ${legacyMediaQueryTokenShim "localhost:8008"}
        # Tuwunel serves MatrixRTC transport discovery, including CORS preflights.
        reverse_proxy /_matrix/* localhost:8008
        # Stylesheet and script of Tuwunel's SSO pages (UIA confirmation, sign-in).
        reverse_proxy /_tuwunel/sso/* localhost:8008
        # Tuwunel's built-in OIDC authorization server (MSC3861 / next-gen auth).
        reverse_proxy /_tuwunel/oidc/* localhost:8008
        reverse_proxy /.well-known/openid-configuration localhost:8008
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
          not path /_matrix/* /_tuwunel/sso/* /_tuwunel/oidc/* /.well-known/openid-configuration /v1/local-mindroom/* /.well-known/matrix/* /livekit/* /
          file {path} /index.html
        }
        rewrite @siteFiles {file_match.relative}
        file_server
      '';
    };

    # Demo Matrix homeserver for TestFlight/App Review password-only testing.
    virtualHosts."${demoDomain}" = {
      logFormat = redactedAccessLogFormat demoDomain;
      extraConfig = ''
        @demoRegistration path /_matrix/client/r0/register* /_matrix/client/v3/register* /_matrix/client/unstable/register*
        respond @demoRegistration 403

        ${legacyMediaQueryTokenShim "localhost:${toString demoTuwunelPort}"}
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
        # AGPL-3.0 section 13 source offer for Sygnal v0.17.0 + mindroom-sygnal.
        @sourceOffer {
          method GET HEAD
          path /
        }
        handle @sourceOffer {
          header Content-Type "text/plain; charset=utf-8"
          respond 200 {
            body <<EOF
            MindRoom Matrix push gateway (Sygnal v0.17.0, AGPL-3.0, with mindroom-sygnal).
            Corresponding source:
            - Sygnal v0.17.0: https://github.com/element-hq/sygnal/tree/v0.17.0
            - mindroom-sygnal: https://github.com/mindroom-ai/mindroom-sygnal/tree/${mindroom-sygnal.rev}
            EOF
          }
        }

        handle {
          reverse_proxy localhost:5000
        }
      '';
    };
  };
}
