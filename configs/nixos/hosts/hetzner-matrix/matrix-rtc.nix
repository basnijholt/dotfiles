# MatrixRTC backend for Element Call voice/video calls on mindroom.chat.
#
# LiveKit SFU carries the call media; lk-jwt-service (the MatrixRTC
# authorization service) exchanges Matrix OpenID tokens for LiveKit JWTs.
# Both are reverse-proxied under https://<siteDomain>/livekit/* by Caddy
# (see caddy.nix), so no extra DNS records are needed. The client discovers
# the service via org.matrix.msc4143.rtc_foci in /.well-known/matrix/client.
{ config, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain rtcJwtPort;
in
{
  services.livekit = {
    enable = true;
    keyFile = config.age.secrets.livekit-keys.path;
    settings = {
      port = 7880;
      rtc = {
        use_external_ip = true;
        tcp_port = 7881;
        port_range_start = 50100;
        port_range_end = 50200;
      };
      # lk-jwt-service creates rooms for full-access homeservers; without
      # this, the SFU creates a room for anyone holding a valid JWT.
      room.auto_create = false;
    };
  };

  services.lk-jwt-service = {
    enable = true;
    livekitUrl = "wss://${siteDomain}/livekit/sfu";
    keyFile = config.age.secrets.livekit-keys.path;
    port = rtcJwtPort;
  };
  # Required since lk-jwt-service 0.9.0: only users of these homeservers may
  # create LiveKit rooms. Only siteDomain advertises this RTC focus.
  systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = siteDomain;

  # WebRTC media goes directly to the SFU, not through Caddy.
  networking.firewall = {
    allowedTCPPorts = [ 7881 ];
    allowedUDPPortRanges = [
      {
        from = 50100;
        to = 50200;
      }
    ];
  };
}
