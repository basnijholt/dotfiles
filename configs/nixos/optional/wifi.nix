# WiFi configuration with agenix secret management
#
# This module configures WiFi using NetworkManager with the PSK
# stored as an agenix secret.
#
# Usage:
#   1. Set my.wifi.ssid to your network name
#   2. Create secrets/wifi-psk.age containing just: WIFI_PSK=yourpassword
#      $ echo "WIFI_PSK=yourpassword" | agenix -e wifi-psk.age
#   3. Import this module on hosts that need WiFi
{ config, lib, ... }:

let
  cfg = config.my.wifi;
in
{
  options.my.wifi = {
    enable = lib.mkEnableOption "WiFi with agenix-managed PSK";

    ssid = lib.mkOption {
      type = lib.types.str;
      description = "WiFi network SSID.";
      example = "MyHomeNetwork";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = cfg.ssid;
      description = "NetworkManager profile name (defaults to SSID).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure NetworkManager is enabled
    networking.networkmanager.enable = true;

    # Decrypt WiFi PSK at activation
    # The file should contain: WIFI_PSK=yourpassword
    age.secrets.wifi-psk = {
      file = ../secrets/wifi-psk.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };

    # Tell NetworkManager to read environment variables from the secret file
    networking.networkmanager.ensureProfiles.environmentFiles = [
      config.age.secrets.wifi-psk.path
    ];

    # NetworkManager profile using $WIFI_PSK from the environment file
    networking.networkmanager.ensureProfiles.profiles.${cfg.profileName} = {
      connection = {
        id = cfg.profileName;
        type = "wifi";
      };
      wifi = {
        mode = "infrastructure";
        ssid = cfg.ssid;
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "$WIFI_PSK";
      };
      ipv4 = { method = "auto"; };
      ipv6 = { method = "auto"; };
    };

    # Disable WiFi power saving for stability
    networking.networkmanager.settings."connection"."wifi.powersave" = 2;
  };
}
