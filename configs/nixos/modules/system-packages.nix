{ pkgs, ... }:

let
  guiApplications = with pkgs; [
    # GUI Applications
    _1password-gui
    brave
    code-cursor
    cryptomator
    dropbox
    filebot
    firefox
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
    _1password-cli
    act
    asciinema
    atuin
    azure-cli
    bat
    btop
    claude-code
    codex
    coreutils
    docker
    dnsutils # Provides dig, nslookup, host
    duf
    eza
    fastfetch
    fzf
    gemini-cli
    google-cloud-sdk
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
    pinentry-gnome3
    postgresql
    psmisc # For killall
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
