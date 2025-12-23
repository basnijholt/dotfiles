# System packages shared by all hosts
#
# Large packages are in optional/large-packages.nix
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
    claude-code
    coreutils
    cups # lp command for network printing
    docker
    devbox
    dnsutils # Provides dig, nslookup, host
    duf
    eza
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
    nixfmt-rfc-style
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
  ];

  # --- Yazi preview dependencies ---
  yaziPreviewDeps = with pkgs; [
    file # MIME type detection
  ];

  # --- Development Toolchains ---
  developmentToolchains = with pkgs; [
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
