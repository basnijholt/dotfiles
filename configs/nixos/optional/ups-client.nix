# NUT network client - connects to UPS server on hp
{ ... }:

{
  power.ups = {
    enable = true;
    mode = "netclient";

    upsmon = {
      monitor.cyberpower = {
        system = "cyberpower@hp.local:3493";
        user = "upsmon";
        passwordFile = "/etc/nut/upsmon.password";
        type = "secondary";
      };
      settings = {
        MINSUPPLIES = 1;
        SHUTDOWNCMD = "/run/current-system/sw/bin/shutdown -h now";
        FINALDELAY = 5;
      };
    };
  };

  # Same password as server
  environment.etc."nut/upsmon.password" = {
    text = "upsmonpass";
    mode = "0600";
    user = "nut";
    group = "nut";
  };
}
