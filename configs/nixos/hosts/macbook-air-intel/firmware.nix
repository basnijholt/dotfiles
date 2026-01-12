{ pkgs, ... }:

{
  hardware.firmware = [
    (pkgs.runCommand "apple-wifi-firmware" { } ''
      mkdir -p $out/lib/firmware/brcm
      if [ -d "${./firmware/brcm}" ]; then
        cp ${./firmware/brcm}/* $out/lib/firmware/brcm/
      else
        echo "Warning: No firmware found in ${./firmware/brcm}. WiFi will not work until you run save-wifi-firmware."
      fi
    '')
  ];
}
