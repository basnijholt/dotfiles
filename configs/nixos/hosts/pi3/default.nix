# Raspberry Pi 3 - simple SD card setup with WiFi
#
# Uses nixos-raspberrypi flake for U-Boot boot with WiFi firmware.
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/wifi.nix

    # Host-specific modules (Tier 3)
    ./hardware-configuration.nix
    ./networking.nix
  ];

  # WiFi configuration (PSK managed by agenix)
  my.wifi = {
    enable = true;
    ssid = "YOUR_SSID_HERE"; # TODO: Replace with your WiFi SSID
  };
}
