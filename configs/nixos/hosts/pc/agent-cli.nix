# Agent CLI server daemon (PC-only)
{ config, pkgs, ... }:

let
  homeDir = config.users.users.basnijholt.home;
in
{
  systemd.user.services."uvx-agent-cli" = {
    description = "uvx agent-cli server";
    wantedBy = [ "default.target" ];
    path = [ pkgs.ffmpeg pkgs.uv ];
    environment.UV_PYTHON = "3.13";
    serviceConfig = {
      ExecStart = "${pkgs.uv}/bin/uvx --from 'agent-cli[server]' agent-cli server";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = homeDir;
    };
  };
}
