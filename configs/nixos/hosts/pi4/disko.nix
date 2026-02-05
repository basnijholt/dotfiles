{ ... }:
(import ../../common/disko-zfs.nix) {
  device = "/dev/disk/by-id/usb-Samsung_Portable_SSD_T5_1234567A666E-0:0";
  espLabel = "ESP";
}
