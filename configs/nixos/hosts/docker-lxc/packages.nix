# Packages for docker-lxc
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    chromium
    ffmpeg
  ];
}
