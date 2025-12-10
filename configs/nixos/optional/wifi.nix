# WiFi with agenix-managed credentials
# Usage: encrypt with: echo -e "WIFI_SSID=MyNetwork\nWIFI_PSK=mypassword" | agenix -e wifi.age
{ config, lib, ... }:

{
  options.my.wifi.enable = lib.mkEnableOption "WiFi with agenix credentials";

  config = lib.mkIf config.my.wifi.enable {
    networking.networkmanager.enable = true;
    networking.networkmanager.settings."connection"."wifi.powersave" = 2;

    age.secrets.wifi.file = ../secrets/wifi.age;

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.age.secrets.wifi.path ];
      profiles."home" = {
        connection = { id = "home"; type = "wifi"; };
        wifi = { mode = "infrastructure"; ssid = "$WIFI_SSID"; };
        wifi-security = { key-mgmt = "wpa-psk"; psk = "$WIFI_PSK"; };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
