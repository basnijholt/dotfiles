# T3 Code for coding agents on the NAS's spare cores, proxied via
# t3dev.lab.nijho.lt (Traefik in docker-lxc). Kept out of default.nix
# because docker-lxc imports that file.
{ ... }:

{
  local.t3code = {
    enable = true;
    host = "0.0.0.0";
  };
  networking.firewall.allowedTCPPorts = [ 3773 ];
}
