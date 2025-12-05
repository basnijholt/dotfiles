{
  networking.networkmanager.ensureProfiles.profiles = {
    "Home-WiFi" = {
      connection = {
        id = "Home-WiFi";
        type = "wifi";
      };
      wifi = {
        mode = "infrastructure";
        ssid = "SSID_HERE";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "PASSWORD_HERE";
      };
      ipv4 = { method = "auto"; };
      ipv6 = { method = "auto"; };
    };
  };
}
