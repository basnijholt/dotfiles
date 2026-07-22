# Raspberry Pi 4 - lightweight headless server
#
# Uses nixos-raspberrypi flake for U-Boot boot with WiFi firmware.
{ lib, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/virtualization.nix
    ../../optional/zfs-replication.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./zfs-unlock-client.nix
  ];

  # Required for ZFS
  networking.hostId = "dc0bd73a";

  # The nixos-raspberrypi nixpkgs (25.11) marks docker-28.5.2 insecure
  # ("unmaintained, use docker_29+"), which blocks comin's eval of this
  # host. Accept it; drop once the rpi branch ships a newer docker.
  nixpkgs.config.permittedInsecurePackages = [ "docker-28.5.2" ];

  # incus-lts v6 on that branch has nine unpatched CVEs and nixpkgs dropped
  # support for it entirely; pi4 runs no incus instances, so disable it
  # instead of permitting it. (virtualization.nix enables it fleet-wide.)
  virtualisation.incus.enable = lib.mkForce false;
}
