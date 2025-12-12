# Installer ISO configuration
# SSH is enabled with key-only auth; root login allowed but NO passwords.
{ pkgs, nixos-hardware, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;
in
{
  imports = [
    nixos-hardware.nixosModules.apple-t2
  ];

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
