# NUC-specific packages (living room media box)
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kodi
  ];
}
