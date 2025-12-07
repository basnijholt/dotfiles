# Raspberry Pi 3 - debug host for Pi boot issues (UEFI boot)
#
# Uses pftf/RPi3 UEFI firmware for standard NixOS boot with ZFS.
# Used to debug boot issues with HDMI/ethernet before deploying to Pi 4.
{ ... }:

{
  imports = [
    # Host-specific modules
    ./networking.nix
  ];

  # Required for ZFS (different from pi4)
  networking.hostId = "a1b2c3d4";
}
