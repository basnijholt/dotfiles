{ lib, ... }:

{
  networking = {
    hostName = lib.mkForce "gce-vm";
    useDHCP = lib.mkDefault true;
    nameservers = lib.mkForce [ "169.254.169.254" ];
    nftables.enable = true;
    firewall.enable = true;
    firewall.interfaces.tailscale0.allowedTCPPorts = [ 3773 ];
  };
}
