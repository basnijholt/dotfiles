{ pkgs, ... }:

let
  guiApps = with pkgs; [
    firefox
    chromium
    vlc
    kodi
  ];

  cliApps = with pkgs; [
    curl
    git
    htop
    jq
    ripgrep
    tmux
    unzip
    wget
  ];
in
{
  environment.systemPackages = guiApps ++ cliApps;
}
