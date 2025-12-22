# Wake-on-LAN via ethtool
{ config, lib, pkgs, ... }:

{
  options.local.wakeOnLan.interface = lib.mkOption {
    type = lib.types.str;
    description = "Network interface for WoL";
  };

  config = {
    systemd.services.wake-on-lan = {
      description = "Enable Wake-on-LAN";
      after = [ "network-pre.target" ];
      before = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ethtool}/bin/ethtool -s ${config.local.wakeOnLan.interface} wol g";
      };
    };
  };
}
