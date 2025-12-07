# Raspberry Pi 4 - lightweight headless server (UEFI boot)
#
# Uses pftf/RPi4 UEFI firmware for standard NixOS boot with ZFS.
# Vanilla aarch64 NixOS - no special Pi flake needed.
#
# Excluded optional modules (too heavy or incompatible with RPi4):
#   - iscsi.nix (no TrueNAS LUNs needed)
#   - desktop.nix, audio.nix, gui-packages.nix (headless)
#   - power.nix (no lid/power button)
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/virtualization.nix
    ../../optional/zfs-replication.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  # Required for ZFS
  networking.hostId = "dc0bd73a";
}
