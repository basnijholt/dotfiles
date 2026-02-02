# Paul's Wyse 5070 - Gateway to home services via Tailscale
#
# A minimal thin client that provides access to home network services
# for devices on Paul's local network. His router points DNS at this
# machine, which resolves *.local to itself and proxies requests home.
#
# Network flow:
#   Device → DNS (*.local) → Wyse CoreDNS → Caddy → Tailscale → Home services
{ lib, ... }:

{
  imports = [
    ./networking.nix
    ./coredns.nix
    ./caddy.nix
    ./jellyfin.nix
    ./librespeed.nix
  ];

  # --- Disable services not needed on a gateway ---
  services.fwupd.enable = lib.mkForce false;
  services.syncthing.enable = lib.mkForce false;
  services.comin.enable = lib.mkForce false; # Manual updates only (low RAM)

  # --- Tailscale for secure tunnel to home network ---
  services.tailscale.enable = lib.mkForce true;

  # --- Override DNS settings (not on home network) ---
  # Use local CoreDNS, fallback to public DNS
  networking.nameservers = lib.mkForce [ "127.0.0.1" "1.1.1.1" "8.8.8.8" ];
  services.resolved.enable = lib.mkForce false; # CoreDNS handles DNS

  # --- Limit build resources (thin client has limited RAM) ---
  nix.settings.max-jobs = 1;
  nix.settings.cores = 2;

  # Zram swap - compressed RAM swap for builds
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Remove local network cache (not reachable from Paul's network)
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];
}
