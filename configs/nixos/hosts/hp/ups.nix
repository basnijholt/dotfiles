# APC UPS monitoring with apcupsd
{ pkgs, ... }:

{
  services.apcupsd = {
    enable = true;
    configText = ''
      UPSNAME apc-ups
      UPSCABLE usb
      UPSTYPE usb
      DEVICE

      POLLTIME 60

      # Shutdown when battery <= 20% or <= 30 minutes remaining
      ONBATTERYDELAY 6
      BATTERYLEVEL 20
      MINUTES 30

      # Network information server for remote monitoring
      NETSERVER on
      NISPORT 3551
      NISIP 0.0.0.0
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

  networking.firewall.allowedTCPPorts = [ 3551 ];
}
