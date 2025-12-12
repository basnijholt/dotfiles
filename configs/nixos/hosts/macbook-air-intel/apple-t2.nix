# Apple T2 Firmware Extraction Tool
# Sourced from: https://github.com/t2linux/nixos-t2-iso/blob/main/nix/pkgs/firmware-script.nix
# This script extracts WiFi/Bluetooth firmware from the macOS partition.
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.stdenvNoCC.mkDerivation {
      pname = "get-apple-firmware";
      version = "360156db52c03dbdac0ef9d6e2cebbca46b955b";
      src = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/t2linux/wiki/360156db52c03dbdac0ef9d6e2cebbca46b955b/docs/tools/firmware.sh";
        hash = "sha256-IL7omNdXROG402N2K9JfweretTnQujY67wKKC8JgxBo=";
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        cp $src $out/bin/get-apple-firmware
        chmod +x $out/bin/get-apple-firmware
      '';
      meta.mainProgram = "get-apple-firmware";
    })
  ];
}
