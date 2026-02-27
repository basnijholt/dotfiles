# Minimal first-stage config for nixos-anywhere in rescue mode.
#
# This intentionally avoids common modules/packages to keep the bootstrap
# closure small enough for Hetzner rescue-mode RAM builds.
{ lib, pkgs, ... }:
let
  sshKeys = (import ../../common/ssh-keys.nix).sshKeys;
in
{
  system.stateVersion = "25.05";
  networking.hostName = lib.mkForce "hetzner-bootstrap";

  # Required for ZFS pool import on boot.
  networking.hostId = "a1b2c3d4";

  users.users.basnijholt = {
    isNormalUser = true;
    description = "Bas Nijholt";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = sshKeys;
  };

  users.users.root.openssh.authorizedKeys.keys = sshKeys;
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      UseDns = false;
    };
  };

  programs.zsh.enable = true;

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" "100.100.100.100" ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "basnijholt" ];
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  environment.systemPackages = with pkgs; [ git ];
}
