{ lib, ... }:

{
  networking.hostName = lib.mkForce "nuc";

  networking.firewall.allowedTCPPorts = [ ];
}
