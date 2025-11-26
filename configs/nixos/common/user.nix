{ pkgs, config, ... }:

let
  homeDir = config.users.users.basnijholt.home;
in
{
  # ===================================
  # User Configuration
  # ===================================
  users.users.basnijholt = {
    isNormalUser = true;
    description = "Bas Nijholt";
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "incus-admin" ];
    shell = pkgs.zsh;
    hashedPassword = "$6$T/TCI6tBzEsNPNfQ$IKq2xf1/2gFwVyvF65dRFc5Mex60jtoSAcCtm8jFMIUc3R63OLnxMx7j2RMSMrwX7C9Jhth9KyhdEa5RSijGs.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMRmEP/ZUShYdZj/h3vghnuMNgtWExV+FEZHYyguMkX basnijholt@blink"
    ];
  };

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

  # Keep the uvx agent-cli server available for local automation tooling.
  systemd.user.services."uvx-agent-cli" = {
    description = "uvx agent-cli server";
    wantedBy = [ "default.target" ];
    path = [ pkgs.ffmpeg pkgs.uv ];
    serviceConfig = {
      ExecStart = "${pkgs.uv}/bin/uvx agent-cli server";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = homeDir;
    };
  };
}
