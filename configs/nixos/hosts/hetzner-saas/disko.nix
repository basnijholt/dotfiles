# Hetzner Cloud x86_64 disk configuration with ZFS (CPX, UEFI boot).
#
# Standard fleet layout from common/disko-zfs.nix: ESP + zroot with
# root/nix/var/home datasets. Only ever applied via nixos-anywhere: disko
# takes effect at install time, and switching a running system onto
# mismatched filesystem config would brick its next boot.
(import ../../common/disko-zfs.nix) {
  device = "/dev/sda";
  espLabel = "ESP-SAAS";
}
