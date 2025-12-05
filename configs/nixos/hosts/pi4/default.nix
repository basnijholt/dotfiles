# Raspberry Pi 4 - lightweight headless server
#
# Minimal configuration keeping the same "feel" as other hosts
# while respecting RPi4's resource constraints.
#
# Excluded optional modules (too heavy for RPi4):
#   - iscsi.nix (no TrueNAS LUNs needed)
#   - desktop.nix, audio.nix, gui-packages.nix (headless)
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/power.nix
    ../../optional/virtualization.nix
    ../../optional/zfs-replication.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  # Required for ZFS
  networking.hostId = "dc0bd73a";
}
