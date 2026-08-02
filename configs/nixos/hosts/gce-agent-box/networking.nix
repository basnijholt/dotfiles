{ lib, ... }:

{
  networking = {
    hostName = lib.mkForce "gce-agent-box";
    useDHCP = lib.mkDefault true;
    nameservers = lib.mkForce [ "169.254.169.254" ];
  };
}
