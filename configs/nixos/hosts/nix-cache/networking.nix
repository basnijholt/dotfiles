# Network configuration for nix-cache
{ ... }:

{
  networking.hostName = "nix-cache";
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # --- Firewall ---
  networking.firewall.allowedTCPPorts = [
    5000 # Harmonia binary cache
  ];

  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; } # mosh
  ];
}
