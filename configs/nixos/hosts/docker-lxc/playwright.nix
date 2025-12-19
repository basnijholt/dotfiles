# Playwright testing dependencies
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    chromium
  ];
}
