# Storage helper daemon
{ config, pkgs, ... }:

let
  user = "basnijholt";
  home = config.users.users.${user}.home;
in
{
  systemd.services.storage-helper = {
    description = "Storage Helper Daemon";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = user;
      Group = "users";
      ExecStart = "${pkgs.uv}/bin/uvx truenas-unlock --daemon";
      Restart = "on-failure";
      RestartSec = "10s";

      # Environment for user-specific paths
      Environment = [
        "HOME=${home}"
        "XDG_CONFIG_HOME=${home}/.config"
      ];
    };
  };
}
