# Raspberry Pi 3 - debug host for Pi boot issues
#
# Uses nixos-raspberrypi flake for U-Boot boot with WiFi firmware.
# Debug host with HDMI/ethernet for troubleshooting boot issues.
{ ... }:

{
  imports = [
    # Host-specific modules
    ./networking.nix
  ];

  # Required for ZFS (different from pi4)
  networking.hostId = "a1b2c3d4";
}
