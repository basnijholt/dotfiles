{ pkgs, ... }:

let
  guiApplications = with pkgs; [
    # GUI Applications
    _1password-gui
    _1password-cli
    brave
    code-cursor
    cryptomator
    docker
    dropbox
    filebot
    firefox
    google-cloud-sdk
    handbrake
    inkscape
    moonlight-qt
    mullvad-vpn
    obs-studio
    obsidian
    qbittorrent
    signal-desktop
    slack
    spotify
    telegram-desktop
    tor-browser-bundle-bin
    vlc
    vscode
  ];

  cliPowerTools = with pkgs; [
    # CLI Power Tools & Utilities
    act
    asciinema
    atuin
    azure-cli
    bat
    btop
    claude-code
    codex
    coreutils
    dnsutils # Provides dig, nslookup, host
    duf
    eza
    fastfetch
    fzf
    gemini-cli
    gh
    git
    git-filter-repo
    git-lfs
    git-secret
    gnugrep
    gnupg
    gnused
    hcloud
    htop
    iperf3
    jq
    just
    k9s
    keyd
    lazydocker
    lazygit
    libnotify
    lm_sensors
    lsof
    micro
    neovim
    nixfmt-rfc-style
    nmap
    packer
    parallel
    pavucontrol
    pinentry-gnome3
    postgresql
    psmisc # For killall
    pulseaudio
    pwgen
    rclone
    ripgrep
    starship
    tealdeer
    terraform
    tmux
    tree
    typst
    wget
    xclip
    xsel
    yq-go
    zellij
  ];

  developmentToolchains = with pkgs; [
    # Development Toolchains
    bun
    cargo
    cmake
    gcc
    go
    gnumake
    meson
    nodejs_20
    openjdk
    pkg-config
    pnpm
    portaudio
    (python3.withPackages (ps: [ ps.pipx ]))
    yarn
  ];

  terminalsAndAlternatives = with pkgs; [
    # Terminals & Linux-native Alternatives
    alacritty
    baobab
    flameshot
    ghostty
    kitty
    opensnitch
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
  ];
in
{
  # ===================================
  # System Packages
  # ===================================
  environment.systemPackages =
    guiApplications
    ++ cliPowerTools
    ++ developmentToolchains
    ++ terminalsAndAlternatives
    ++ hyprlandEssentials;
}
