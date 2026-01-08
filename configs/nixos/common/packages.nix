# System packages shared by all hosts
#
# Large packages are in optional/large-packages.nix
# See scripts/nix/package-marginal-cost.py for analysis of "marginal cost"
{ pkgs, ... }:

let
  # --- CLI Power Tools & Utilities ---
  cliPowerTools = with pkgs; [
    _1password-cli
    act
    asciinema
    atuin
    bandwhich
    bat
    btop
    coreutils
    cups # lp command for network printing
    docker
    devbox
    dnsutils # Provides dig, nslookup, host
    duf
    eza
    fd
    fzf
    gh
    git
    git-filter-repo
    git-lfs
    git-secret
    gnugrep
    gnupg
    gnused
    gping
    hcloud
    htop
    iperf3
    jq
    just
    keyd
    lazydocker
    lazygit
    lm_sensors
    lsof
    micro
    mosh
    neovim
    nixfmt
    nmap
    packer
    parallel
    postgresql
    procs
    psmisc # For killall
    pwgen
    rclone
    ripgrep
    starship
    tealdeer
    terraform
    tmux
    tokei
    tre-command
    tree
    typst
    unzip
    usbutils
    wakeonlan
    wget
    yazi-unwrapped
    yq-go
    zellij
    zoxide
  ];

  # --- Yazi preview dependencies ---
  yaziPreviewDeps = with pkgs; [
    file # MIME type detection
  ];

  # --- Development Toolchains ---
  developmentToolchains = with pkgs; [
    bun
    gcc
    gnumake
    meson
    nodejs_20
    pkg-config
    portaudio
    (python3.withPackages (ps: [ ps.pipx ]))
  ];
in
{
  environment.systemPackages =
    cliPowerTools
    ++ yaziPreviewDeps
    ++ developmentToolchains;
}
