# Installer ISO configuration
# SSH is enabled with key-only auth; root login allowed but NO passwords.
{ pkgs, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;
in
{
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

  # Make the ISO self-sufficient for flake-based installs run headless over SSH
  # (e.g. the NAS cutover: `nix run …disko` + `nixos-install --flake`).
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  environment.systemPackages = with pkgs; [ git ];
}
