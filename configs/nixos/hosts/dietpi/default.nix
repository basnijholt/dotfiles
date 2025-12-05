# Raspberry Pi 4 - lightweight headless server
#
# Minimal configuration keeping the same "feel" as other hosts
# while respecting RPi4's resource constraints.
#
# Excluded optional modules (too heavy for RPi4):
#   - virtualization.nix (Docker/libvirt/Incus too resource-intensive)
#   - iscsi.nix (no TrueNAS LUNs needed)
#   - zfs-replication.nix (no ZFS on SD card)
#   - desktop.nix, audio.nix, gui-packages.nix (headless)
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/power.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];
}
