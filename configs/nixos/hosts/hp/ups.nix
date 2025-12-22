# CyberPower UPS monitoring with NUT
{ ... }:

{
  power.ups = {
    enable = true;
    mode = "netserver";

    ups.cyberpower = {
      driver = "usbhid-ups";
      port = "auto";
      description = "CyberPower CP1500PFCLCD";
      directives = [
        "override.battery.charge.low = 20"
        "override.battery.runtime.low = 1800"  # 30 minutes in seconds
      ];
    };

    users.upsmon = {
      upsmon = "primary";
      passwordFile = "/etc/nut/upsmon.password";
    };

    upsd.listen = [
      { address = "0.0.0.0"; port = 3493; }
    ];

    upsmon = {
      monitor.cyberpower = {
        system = "cyberpower@localhost";
        user = "upsmon";
        passwordFile = "/etc/nut/upsmon.password";
        type = "primary";
      };
      settings = {
        MINSUPPLIES = 1;
        SHUTDOWNCMD = "/run/current-system/sw/bin/shutdown -h now";
        FINALDELAY = 5;
      };
    };
  };

  # Create password file
  environment.etc."nut/upsmon.password" = {
    text = "upsmonpass";
    mode = "0600";
    user = "nut";
    group = "nut";
  };

  networking.firewall.allowedTCPPorts = [ 3493 ];
}
