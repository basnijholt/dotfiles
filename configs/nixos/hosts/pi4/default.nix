# Raspberry Pi 4 - lightweight headless server
#
# Uses nixos-raspberrypi flake for U-Boot boot with WiFi firmware.
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/virtualization.nix
    ../../optional/zfs-replication.nix
    ../../optional/wifi.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  # Required for ZFS
  networking.hostId = "dc0bd73a";

  # WiFi configuration (PSK managed by agenix)
  my.wifi = {
    enable = true;
    ssid = "YOUR_SSID_HERE"; # TODO: Replace with your WiFi SSID
  };
}
