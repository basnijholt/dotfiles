# Hetzner Cloud VPS - minimal Docker Compose host
#
# A lightweight host for running Docker Compose stacks (websites, services).
# Uses common packages but excludes optional/large-packages.nix.
{ lib, pkgs, ... }:

{
  imports = [
    # Optional modules
    ../../optional/zfs-auto-snapshot.nix

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

  # Allow root SSH for TrueNAS ZFS pull replication
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    # TrueNAS-generated key for ZFS pull replication
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIq7zPtq0+tNrz1xbX+Fo7fVnfMtbmEHeiKclcicK7b0qz/LunbYDA/dfKi2EgrFbbkQuMoUBsb8HcEP+KCuzZqepGl3r0aRL3wC+ZMSMeoVMOrjpoI7NAQtGD5IJ1Aa5jIMi+FWzHydNG7QVMMSA+AiIUIkfQxCqji/xGaDK0HiPu86CGqMsBDLLpAsYmCdoivqkaGYEi9ifZreOO9508gP7ph//7MriKw1A9KOUdOMfJkpGLs69bFz54s7Dl7L5QhxWOPpI3yrJZpP5kM8rW5uc74wdUkhH4x03mU0zUF48H+SdUe4xtVjKc7DAhgERXNVjzmfSY0kD2AjxbEJzfFl2c2s7rd+i9AOUvn7vgRLcbMbFY5O24qFxdPEcynJGAvbTQG388ZACcSBFc/uXZJXMeupzTXjbjBjyL2gODwnMG9r52Wuzs4tuhTPjoCltU67yT5Ya+ZLM20Pp1NpiAZq4Bfp6xIKtnm3tfciaeiOTSaAaOyNc1skDsbjW8Qg0= root@truenas hetzner-key"
  ];

  # Remove local network cache (not reachable from Hetzner)
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];

  # Limit build parallelism to prevent OOM on small VPS
  nix.settings.max-jobs = 1;
  nix.settings.cores = 1;

  # Zram swap - compressed RAM swap for builds (ZFS doesn't support swapfiles well)
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Use up to 50% of RAM for compressed swap
  };

  # Required for ZFS
  networking.hostId = "027a1bbc";
  # ZFS 2.4.0 pin is in hardware-configuration.nix
}
