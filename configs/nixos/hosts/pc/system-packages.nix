{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    _1password-gui
    code-cursor
    cryptomator
    cudatoolkit
    dropbox
    filebot
    handbrake
    inkscape
    llama-cpp
    moonlight-qt
    mullvad-vpn
    nvtopPackages.full
    obs-studio
    obsidian
    ollama
    qbittorrent
    rust-analyzer
    signal-desktop
    slack
    spotify
    telegram-desktop
    tor-browser-bundle-bin
    vlc
    winetricks
  ];
}
