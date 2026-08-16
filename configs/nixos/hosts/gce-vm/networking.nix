{ lib, ... }:

{
  networking = {
    hostName = lib.mkForce "gce-vm";
    useDHCP = lib.mkDefault true;
    nameservers = lib.mkForce [ "169.254.169.254" ];
    firewall.interfaces.tailscale0.allowedTCPPorts = [ 3773 ];
  };
}
