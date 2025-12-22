# apcupsd network client - connects to UPS server on hp
{ pkgs, ... }:

{
  services.apcupsd = {
    enable = true;
    configText = ''
      UPSNAME apc-ups
      UPSCABLE ether
      UPSTYPE net
      DEVICE hp.local:3551

      POLLTIME 60

      # Shutdown when battery <= 20% or <= 30 minutes remaining
      ONBATTERYDELAY 6
      BATTERYLEVEL 20
      MINUTES 30
    '';
    hooks = {
      onbattery = ''
        echo "Power failure - running on battery" | ${pkgs.systemd}/bin/systemd-cat -t apcupsd
      '';
      offbattery = ''
        echo "Power restored" | ${pkgs.systemd}/bin/systemd-cat -t apcupsd
      '';
      doshutdown = ''
        echo "UPS triggered shutdown" | ${pkgs.systemd}/bin/systemd-cat -t apcupsd
      '';
    };
  };
}
