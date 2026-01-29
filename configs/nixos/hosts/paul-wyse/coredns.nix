# Minimal CoreDNS for Paul's Wyse 5070
#
# Resolves *.local to localhost (for Caddy reverse proxy)
# Forwards all other queries upstream
{ pkgs, lib, ... }:

let
  # Simple zone: all .local queries resolve to localhost
  localZone = pkgs.writeText "local.zone" ''
    $ORIGIN local.
    @   900   IN  SOA   ns hostadmin 1 900 300 604800 900
    @   3600  IN  NS    ns
    ns  3600  IN  A     127.0.0.1
    *   3600  IN  A     127.0.0.1
  '';
in
{
  services.coredns = {
    enable = true;
    config = ''
      local {
        bind 0.0.0.0
        file ${localZone}
      }

      . {
        bind 0.0.0.0
        forward . 1.1.1.1 8.8.8.8
        cache 300
        errors
      }
    '';
  };

  # Ensure CoreDNS waits for network
  systemd.services.coredns = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = "5s";
      StartLimitIntervalSec = 0;
    };
  };
}
