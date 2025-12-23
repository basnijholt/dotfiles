# Hetzner Cloud VPS - minimal Docker Compose host
#
# A lightweight host for running Docker Compose stacks (websites, services).
# Excludes large packages from common/packages.nix to minimize closure size.
{ lib, ... }:

{
  imports = [
    # Host-specific modules (Tier 3)
    ./networking.nix
    ./packages.nix
  ];

  # Docker for compose stacks - enabled directly, not via virtualization.nix
  # (which also pulls in libvirt, incus, virt-manager)
  virtualisation.docker.enable = true;

  # Disable services that aren't needed on a web host
  services.fwupd.enable = lib.mkForce false; # No firmware updates on VPS
  services.syncthing.enable = lib.mkForce false; # No file sync needed

  # Required for ZFS
  networking.hostId = "027a1bbc";
}
