# Network configuration for Raspberry Pi 3
{ lib, ... }:

{
  networking.hostName = "pi3";
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # --- WiFi Power Management ---
  networking.networkmanager.settings."connection"."wifi.powersave" = 2;

  # --- WiFi Configuration (Secret) ---
  # Reuse wifi.nix from pi4 if it exists
  imports = lib.optional (builtins.pathExists ../pi4/wifi.nix) ../pi4/wifi.nix;
}
