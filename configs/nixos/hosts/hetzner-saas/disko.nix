# Hetzner Cloud x86_64 disk configuration with ZFS (CPX, UEFI boot).
#
# Standard fleet layout from common/disko-zfs.nix: ESP + zroot with
# root/nix/var/home datasets. Replaced the original ext4 layout at the
# 2026-07 reinstall; applying this to a running ext4 install would brick
# it — it is only ever applied via nixos-anywhere.
(import ../../common/disko-zfs.nix) {
  device = "/dev/sda";
  espLabel = "ESP-SAAS";
}
