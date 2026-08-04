# Desktop environment (GNOME + Hyprland)
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Hyprland 0.56.1 rejects nixpkgs' glaze 8 only because of its CMake version
  # constraint. Relax it to use the existing nixpkgs package, matching the fix.
  # TODO: Remove this overlay once the nixpkgs fix PR is merged:
  # https://github.com/NixOS/nixpkgs/issues/549201
  # https://github.com/NixOS/nixpkgs/pull/549253
  nixpkgs.overlays = [
    (_final: prev: {
      hyprland = prev.hyprland.overrideAttrs (oldAttrs: {
        postPatch = oldAttrs.postPatch + ''
          substituteInPlace CMakeLists.txt start/CMakeLists.txt hyprpm/CMakeLists.txt \
            --replace-fail "glaze 7...<8" "glaze"
        '';
      });
    })
  ];

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
  # Sunshine runs as a user graphical-session service, so auto-login creates
  # the GNOME session needed for headless Moonlight access after boot.
  services.displayManager.autoLogin = {
    enable = true;
    user = "basnijholt";
  };
  services.displayManager.defaultSession = lib.mkDefault "gnome";
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
      hyprland.default = [
        "hyprland"
        "gtk"
      ];
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
