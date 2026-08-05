# User account configuration
{ pkgs, ... }:

let
  sshKeys = (import ./ssh-keys.nix).sshKeys;
in
{
  users.users.basnijholt = {
    isNormalUser = true;
    description = "Bas Nijholt";
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "incus-admin" ];
    shell = pkgs.zsh;
    # Keep /run/user/<uid> (and zellij sockets in it) alive when the last
    # logind session ends while mosh-server/zellij survive.
    linger = true;
    hashedPassword = "$6$T/TCI6tBzEsNPNfQ$IKq2xf1/2gFwVyvF65dRFc5Mex60jtoSAcCtm8jFMIUc3R63OLnxMx7j2RMSMrwX7C9Jhth9KyhdEa5RSijGs.";
    openssh.authorizedKeys.keys = sshKeys;
  };
}
