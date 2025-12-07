# Declarative Raspberry Pi UEFI firmware module
#
# This module fetches pftf UEFI firmware and installs it to /boot.
# No manual downloading or shell scripts needed.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.raspberry-pi.uefi;

  # pftf UEFI firmware packages
  pftfFirmware = {
    rpi3 = pkgs.fetchzip {
      url = "https://github.com/pftf/RPi3/releases/download/v1.38/RPi3_UEFI_Firmware_v1.38.zip";
      sha256 = "sha256-w3qZ19UxO+vWyM3P/EKhzuMaVAISE+5/gaBVWPf+aWU=";
      stripRoot = false;
    };
    rpi4 = pkgs.fetchzip {
      url = "https://github.com/pftf/RPi4/releases/download/v1.38/RPi4_UEFI_Firmware_v1.38.zip";
      sha256 = "sha256-9tOr80jcmguFy2bSz+H3TfmG8BkKyBTFoUZkMy8x+0g=";
      stripRoot = false;
    };
  };

  firmware = pftfFirmware.${cfg.model};

  # Model-specific file mappings
  firmwareFiles = {
    rpi3 = {
      "RPI_EFI.fd" = "${firmware}/RPI_EFI.fd";
      "config.txt" = "${firmware}/config.txt";
      "bootcode.bin" = "${firmware}/bootcode.bin";
      "fixup.dat" = "${firmware}/fixup.dat";
      "start.elf" = "${firmware}/start.elf";
      "bcm2710-rpi-3-b.dtb" = "${firmware}/bcm2710-rpi-3-b.dtb";
      "bcm2710-rpi-3-b-plus.dtb" = "${firmware}/bcm2710-rpi-3-b-plus.dtb";
      "bcm2710-rpi-cm3.dtb" = "${firmware}/bcm2710-rpi-cm3.dtb";
    };
    rpi4 = {
      "RPI_EFI.fd" = "${firmware}/RPI_EFI.fd";
      "config.txt" = "${firmware}/config.txt";
      "fixup4.dat" = "${firmware}/fixup4.dat";
      "start4.elf" = "${firmware}/start4.elf";
      "bcm2711-rpi-4-b.dtb" = "${firmware}/bcm2711-rpi-4-b.dtb";
      "bcm2711-rpi-400.dtb" = "${firmware}/bcm2711-rpi-400.dtb";
      "bcm2711-rpi-cm4.dtb" = "${firmware}/bcm2711-rpi-cm4.dtb";
    };
  };

in {
  options.hardware.raspberry-pi.uefi = {
    enable = mkEnableOption "pftf UEFI firmware for Raspberry Pi";

    model = mkOption {
      type = types.enum [ "rpi3" "rpi4" ];
      description = "Raspberry Pi model (rpi3 or rpi4)";
    };

    firmware = mkOption {
      type = types.package;
      readOnly = true;
      default = pftfFirmware.${cfg.model};
      description = "The UEFI firmware package for the selected model";
    };
  };

  config = mkIf cfg.enable {
    # Copy UEFI firmware files to /boot via systemd-boot
    boot.loader.systemd-boot.extraFiles = firmwareFiles.${cfg.model};

    # Copy overlays and firmware directories via activation script
    system.activationScripts.pftfFirmware = ''
      # Copy overlays directory if it exists
      if [ -d ${firmware}/overlays ]; then
        mkdir -p /boot/overlays
        cp -r ${firmware}/overlays/* /boot/overlays/ 2>/dev/null || true
      fi
      # Copy firmware directory if it exists
      if [ -d ${firmware}/firmware ]; then
        mkdir -p /boot/firmware
        cp -r ${firmware}/firmware/* /boot/firmware/ 2>/dev/null || true
      fi
    '';
  };
}
