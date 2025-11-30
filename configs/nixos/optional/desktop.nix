# Desktop environment (GNOME + Hyprland)
{ config, pkgs, ... }:

{
  # --- Mechabar Dependencies (Home Manager) ---
  home-manager.users.basnijholt.home.packages = with pkgs; [
    bluetui
    bluez
    brightnessctl
    pipewire
    wireplumber
    rofi
  ];

  # --- X11 & Display Managers ---
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  programs.dconf.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # --- Hyprland ---
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common.default = "gtk";
      hyprland.default = [ "hyprland" "gtk" ];
    };
  };

  # --- GPG Pinentry (GUI) ---
  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gnome3;

  # --- Desktop Applications ---
  programs.thunderbird = {
    enable = true;
    package = pkgs.thunderbird-bin;
  };
}
