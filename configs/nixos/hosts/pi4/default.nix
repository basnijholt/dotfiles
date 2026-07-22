# Raspberry Pi 4 - lightweight headless server
#
# Uses nixos-raspberrypi flake for U-Boot boot with WiFi firmware.
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # No virtualization.nix: this host runs no containers or VMs, and it
    # builds against nixos-raspberrypi's older pinned nixpkgs, where
    # docker_28/incus-lts are insecure-flagged and refuse to evaluate.
    ../../optional/zfs-replication.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./zfs-unlock-client.nix
  ];

  # Required for ZFS
  networking.hostId = "dc0bd73a";
}
