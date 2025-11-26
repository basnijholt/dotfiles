# Kodi media center configuration
{ pkgs, ... }:

{
  # --- Kodi Desktop ---
  services.xserver = {
    enable = true;
    desktopManager.kodi = {
      enable = true;
      package = pkgs.kodi.withPackages (kodiPkgs: with kodiPkgs; [
        youtube
      ]);
    };
  };

  # --- Auto-login to Kodi ---
  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "basnijholt";
    };
    defaultSession = "kodi";
  };

  # --- Xbox Controller Support ---
  hardware.xpadneo.enable = true;
}
