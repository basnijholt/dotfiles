# Disk cleanup defaults shared by hosts.
{ config, lib, ... }:

{
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "daily";
    options = lib.mkDefault "--delete-older-than 30d";
  };

  nix.settings = {
    min-free = lib.mkDefault (2 * 1024 * 1024 * 1024);
    max-free = lib.mkDefault (6 * 1024 * 1024 * 1024);
  };

  virtualisation.docker.autoPrune = lib.mkIf config.virtualisation.docker.enable {
    enable = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    flags = lib.mkDefault [ "--all" ];
  };
}
