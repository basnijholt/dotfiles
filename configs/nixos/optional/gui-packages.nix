# GUI packages for workstations
{ pkgs, ... }:

let
  # --- GUI Applications ---
  guiApplications = with pkgs; [
    brave
    firefox
    vscode
  ];

  # --- Terminals & Linux-native Alternatives ---
  terminalsAndAlternatives = with pkgs; [
    alacritty
    baobab
    flameshot
    ghostty
    kitty
  ];

  # --- Hyprland Essentials ---
  hyprlandEssentials = with pkgs; [
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

  # --- CLI Tools that Require GUI/X11 ---
  guiCliTools = with pkgs; [
    libnotify
    xclip
    xsel
  ];
in
{
  environment.systemPackages =
    guiApplications
    ++ terminalsAndAlternatives
    ++ hyprlandEssentials
    ++ guiCliTools;
}
