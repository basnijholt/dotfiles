{ pkgs, ... }:

let
  # ===================================
  # Living-Room GUI Applications
  # ===================================
  guiApps = with pkgs; [ ];

  # ===================================
  # Living-Room CLI Essentials
  # ===================================
  cliApps = with pkgs; [ ];
in
{
  environment.systemPackages = guiApps;
}
