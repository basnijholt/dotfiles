{ pkgs, ... }:

{
  # ===================================
  # User Configuration
  # ===================================
  users.users.basnijholt = {
    isNormalUser = true;
    description = "Bas Nijholt";
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt"
    ];
  };
  # Run Atuins history daemon using existing ~/.config/atuin/config.toml
  systemd.user.services."atuin-daemon" = {
    description = "Atuin history daemon";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.atuin}/bin/atuin daemon";
      Environment = [ "ATUIN_CONFIG=/home/basnijholt/.config/atuin/config.toml" ];
      Restart = "on-failure";
    };
  };
}
