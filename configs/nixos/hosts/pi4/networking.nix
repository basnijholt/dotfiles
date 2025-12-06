# Network configuration for Raspberry Pi 4
{ lib, ... }:

{
  networking.hostName = "pi4";
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # --- WiFi Power Management ---
  # Disable power saving for server stability
  networking.networkmanager.settings."connection"."wifi.powersave" = 2;

  # --- WiFi Configuration (Secret) ---
  # Import wifi.nix if it exists (contains networking.networkmanager.ensureProfiles...)
  imports = lib.optional (builtins.pathExists ./wifi.nix) ./wifi.nix;

  # Mosh support for flaky connections
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; }
  ];
}
