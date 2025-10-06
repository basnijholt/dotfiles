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
    llama-cpp
    lm_sensors
    lsof
    micro
    neovim
    nixfmt-rfc-style
    nmap
    nvtopPackages.full
    ollama
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
    cudatoolkit
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
    rust-analyzer
    winetricks
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
    waybar # Status bar (most popular by far)
    hyprpanel # Status bar (alternative to waybar)
    wofi # Application launcher (simpler than rofi)
    mako # Notification daemon (Wayland-native)
    swww # Wallpaper daemon (smooth transitions)
    wl-clipboard # Clipboard manager (copy/paste support)
    wl-clip-persist # Clipboard persistence
    cliphist # Clipboard history
    hyprlock # Screen locker
    hyprpicker # Color picker
    hyprshot # Screenshot tool (Hyprland-specific)
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
