# System packages shared by all hosts
#
# Large packages (>50MB marginal) are in optional/large-packages.nix
# Run scripts/package-marginal-cost.py to analyze package sizes.
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
    cups
    docker
    devbox
    dnsutils
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
    psmisc
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

  # --- Yazi preview dependencies (lightweight only) ---
  yaziPreviewDeps = with pkgs; [
    file
    # Heavy previewers in optional/large-packages.nix
  ];

  # --- Development Toolchains (lightweight only) ---
  developmentToolchains = with pkgs; [
    gcc
    gnumake
    meson
    nodejs_20
    pkg-config
    portaudio
    (python3.withPackages (ps: [ ps.pipx ]))
    # Heavy toolchains in optional/large-packages.nix
  ];
in
{
  environment.systemPackages =
    cliPowerTools
    ++ yaziPreviewDeps
    ++ developmentToolchains;
}
