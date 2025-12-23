# Raspberry Pi 3 - simple SD card setup with WiFi
#
# Uses nixos-raspberrypi flake for U-Boot boot with WiFi firmware.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
  ];
}
