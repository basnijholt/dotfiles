# Hetzner Cloud VPS - minimal Docker Compose host
#
# A lightweight host for running Docker Compose stacks (websites, services).
# Uses common packages but excludes optional/large-packages.nix.
{ lib, pkgs, ... }:

{
  imports = [
    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  # Docker for compose stacks - enabled directly, not via virtualization.nix
  # (which also pulls in libvirt, incus, virt-manager)
  virtualisation.docker.enable = true;

  # Google Cloud SDK for deployments
  environment.systemPackages = [ pkgs.google-cloud-sdk ];

  # Disable services that aren't needed on a web host
  services.fwupd.enable = lib.mkForce false; # No firmware updates on VPS
  services.syncthing.enable = lib.mkForce false; # No file sync needed
  services.tailscale.enable = lib.mkForce false; # Not using Tailscale on VPS

  # Fix SSH hanging - disable reverse DNS lookup (override common/services.nix)
  services.openssh.settings.UseDns = lib.mkForce false;

  # Remove local network cache (not reachable from Hetzner)
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];

  # Zram swap - compressed RAM swap for builds (ZFS doesn't support swapfiles well)
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Use up to 50% of RAM for compressed swap
  };

  # Required for ZFS
  networking.hostId = "027a1bbc";
  # ZFS 2.4.0 pin is in hardware-configuration.nix
}
