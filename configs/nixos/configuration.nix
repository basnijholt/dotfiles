# /etc/nixos/configuration.nix
# NixOS -- basnijholt/dotfiles
#
# 3-Tier Module Architecture:
# - common/: Modules shared by ALL hosts (Tier 1)
# - optional/: Modules hosts can opt-in to (Tier 2)
# - hosts/: Host-specific modules (Tier 3)

{ config, pkgs, ... }:

{
  imports = [
    ./common
  ];

  # The system state version is critical and should match the installed NixOS release.
  system.stateVersion = "25.05";
}
