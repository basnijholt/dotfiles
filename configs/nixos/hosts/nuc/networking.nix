{ lib, ... }:

{
  networking.hostName = lib.mkForce "nuc";

  # The shared networking module already enables NetworkManager; no Wi-Fi tweaks needed.

  services.resolved.extraConfig = lib.mkForce ''
    DNS=192.168.1.4 100.100.100.100
  '';

  networking.firewall.allowedTCPPorts = [ ];
}
