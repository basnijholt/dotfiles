# Network configuration for nix-cache
{ ... }:

{
  networking.hostName = "nix-cache";
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # --- Firewall ---
  networking.firewall.allowedTCPPorts = [
    5000 # Harmonia binary cache
  ];
}
