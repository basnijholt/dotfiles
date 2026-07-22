# Raspberry Pi 4 - lightweight headless server
#
# Uses nixos-raspberrypi flake for U-Boot boot with WiFi firmware.
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # No virtualization.nix: verified 2026-07-21 that pi4 ran zero docker
    # containers and zero incus instances, and this host builds against
    # nixos-raspberrypi's older pinned nixpkgs where docker_28/incus-lts
    # are insecure-flagged and refuse to evaluate (this froze pi4's comin
    # deploys after the 2026-07-21 flake bump).
    ../../optional/zfs-replication.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./zfs-unlock-client.nix
  ];

  # Required for ZFS
  networking.hostId = "dc0bd73a";
}
