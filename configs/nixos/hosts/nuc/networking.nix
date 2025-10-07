{ lib, ... }:

{
  networking.hostName = lib.mkForce "nuc";

  # Keep NetworkManager for Wi-Fi and wired management on the NUC.
  networking.networkmanager.enable = true;
  networking.networkmanager.settings."connection"."wifi.powersave" = 2;

  services.resolved = {
    enable = true;
    domains = [ "~local" ];
    extraConfig = ''
      DNS=192.168.1.4 100.100.100.100
    '';
  };

  networking.firewall.allowedTCPPorts = [
    8008 # Synapse / media UI
    9292 # llama-swap (if exposed)
    30080
    30443
  ];
}
