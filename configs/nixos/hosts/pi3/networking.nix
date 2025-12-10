# Network configuration for Raspberry Pi 3
{ ... }:

{
  networking.hostName = "pi3";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  # NetworkManager and WiFi power saving are configured by optional/wifi.nix
}
