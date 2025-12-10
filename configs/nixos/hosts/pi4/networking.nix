# Network configuration for Raspberry Pi 4
{ ... }:

{
  networking.hostName = "pi4";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  # NetworkManager and WiFi power saving are configured by optional/wifi.nix
}
