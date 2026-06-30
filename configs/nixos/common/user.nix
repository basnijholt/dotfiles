# User account configuration
{ config, pkgs, ... }:

let
  homeDir = config.users.users.basnijholt.home;
  sshKeys = (import ./ssh-keys.nix).sshKeys;
in
{
  users.users.basnijholt = {
    isNormalUser = true;
    description = "Bas Nijholt";
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "incus-admin" ];
    shell = pkgs.zsh;
    hashedPassword = "$6$T/TCI6tBzEsNPNfQ$IKq2xf1/2gFwVyvF65dRFc5Mex60jtoSAcCtm8jFMIUc3R63OLnxMx7j2RMSMrwX7C9Jhth9KyhdEa5RSijGs.";
    openssh.authorizedKeys.keys = sshKeys;
  };

  # Colmena deploys over SSH as this user and needs non-interactive privilege
  # escalation for activation because root SSH login is disabled.
  security.sudo.extraRules = [
    {
      users = [ "basnijholt" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # --- Atuin History Daemon ---
  # Run Atuins history daemon using existing ~/.config/atuin/config.toml
  systemd.user.services."atuin-daemon" = {
    description = "Atuin history daemon";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.atuin}/bin/atuin daemon";
      Environment = [ "ATUIN_CONFIG=${homeDir}/.config/atuin/config.toml" ];
      Restart = "on-failure";
    };
  };
}
