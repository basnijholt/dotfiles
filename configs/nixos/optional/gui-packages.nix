{ pkgs, ... }:

let
  guiApplications = with pkgs; [
    # GUI Applications
    brave
    firefox
    vscode
  ];

  terminalsAndAlternatives = with pkgs; [
    # Terminals & Linux-native Alternatives
    alacritty
    baobab
    flameshot
    ghostty
    kitty
  ];

  hyprlandEssentials = with pkgs; [
    # Hyprland Essentials
    polkit_gnome
    waybar
    hyprpanel
    wofi
    mako
    swww
    wl-clipboard
    wl-clip-persist
    cliphist
    hyprlock
    hyprpicker
    hyprshot
    opensnitch
    pavucontrol
    pulseaudio
  ];

  guiCliTools = with pkgs; [
    # CLI tools that require GUI/X11
    libnotify
    xclip
    xsel
  ];
in
{
  # ===================================
  # GUI Packages (workstations only)
  # ===================================
  environment.systemPackages =
    guiApplications
    ++ terminalsAndAlternatives
    ++ hyprlandEssentials
    ++ guiCliTools;
}
