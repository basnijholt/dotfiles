# Installer ISO configuration
# SSH is enabled with key-only auth; root login allowed but NO passwords.
{ pkgs, lib, nixos-hardware, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;
in
{
  imports = [
    nixos-hardware.nixosModules.apple-t2
  ] ++ lib.optional (builtins.pathExists ../hosts/macbook-air-intel/wifi.nix) ../hosts/macbook-air-intel/wifi.nix;

  # Use NetworkManager for WiFi (allows pre-configuring profiles via wifi.nix)
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager = {
    enable = true;
    plugins = lib.mkForce []; # Minimal plugins to save space
  };

  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  users.users.root = {
    initialPassword = "nixos"; # default console password
    openssh.authorizedKeys.keys = sshKeys;
  };
}
