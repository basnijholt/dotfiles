{ config, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    desktopManager.kodi = {
      enable = true;
      package = pkgs.kodi.withPackages (kodiPkgs: with kodiPkgs; [
        youtube
      ]);
    };
  };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "basnijholt";
    };
    defaultSession = "kodi";
  };

  # Xbox controller support
  hardware.xpadneo.enable = true;
}
