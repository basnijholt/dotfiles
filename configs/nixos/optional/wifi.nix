# WiFi with agenix-managed PSK
# Usage: Set my.wifi.ssid, encrypt PSK with: echo "WIFI_PSK=pass" | agenix -e wifi-psk.age
{ config, lib, ... }:

let cfg = config.my.wifi; in
{
  options.my.wifi = {
    enable = lib.mkEnableOption "WiFi with agenix PSK";
    ssid = lib.mkOption { type = lib.types.str; };
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
    networking.networkmanager.settings."connection"."wifi.powersave" = 2;

    age.secrets.wifi-psk.file = ../secrets/wifi-psk.age;

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.age.secrets.wifi-psk.path ];
      profiles.${cfg.ssid} = {
        connection = { id = cfg.ssid; type = "wifi"; };
        wifi = { mode = "infrastructure"; ssid = cfg.ssid; };
        wifi-security = { key-mgmt = "wpa-psk"; psk = "$WIFI_PSK"; };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
