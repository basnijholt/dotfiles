{ pkgs, ... }:

let
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
    lm_sensors
    lsof
    mosh
    micro
    neovim
    nixfmt-rfc-style
    nmap
    packer
    parallel
    postgresql
    psmisc # For killall
    pwgen
    rclone
    ripgrep
    starship
    tealdeer
    terraform
    tmux
    tre-command
    tree
    typst
    wget
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
in
{
  # ===================================
  # System Packages
  # ===================================
  environment.systemPackages =
    cliPowerTools
    ++ developmentToolchains;
}
