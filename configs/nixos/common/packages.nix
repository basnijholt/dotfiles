# System packages shared by all hosts
#
# Large packages (>50MB marginal) are in optional/large-packages.nix
# Run scripts/package-marginal-cost.py to analyze package sizes.
{ pkgs, ... }:

let
  # --- CLI Power Tools & Utilities ---
  # All packages here have <50MB marginal cost
  cliPowerTools = with pkgs; [
    _1password-cli
    act              # +19.5 MB marginal
    asciinema        # +467 KB marginal
    atuin            # +36 MB marginal
    bandwhich        # +4.4 MB marginal
    bat              # +7.5 MB marginal
    btop
    claude-code
    coreutils        # 0 bytes marginal (in base)
    cups             # +15 MB marginal
    docker           # 0 bytes marginal (in baseline)
    devbox           # +29 MB marginal
    dnsutils         # +8.1 MB marginal
    duf              # +3.0 MB marginal
    eza              # +2.4 MB marginal
    fzf              # +4.7 MB marginal
    gh               # +53 MB marginal (borderline, but useful)
    git              # 0 bytes marginal (in baseline)
    git-filter-repo  # +767 KB marginal
    git-lfs          # +12.6 MB marginal
    git-secret       # +19.6 MB marginal
    gnugrep          # 0 bytes marginal
    gnupg            # +19.5 MB marginal
    gnused           # 0 bytes marginal
    gping            # +3.5 MB marginal
    hcloud           # +18 MB marginal
    htop             # +561 KB marginal
    iperf3           # +669 KB marginal
    jq               # +38 KB marginal
    just             # +4.5 MB marginal
    keyd             # +3.6 MB marginal
    lazydocker       # +12.3 MB marginal
    lazygit          # +23 MB marginal
    lm_sensors       # +457 KB marginal
    lsof             # +265 KB marginal
    micro            # +12.7 MB marginal
    mosh             # +36 MB marginal
    neovim           # 0 bytes marginal (in baseline)
    nixfmt-rfc-style # +5.0 MB marginal
    nmap             # +28 MB marginal
    packer
    parallel         # +929 KB marginal
    postgresql       # +25 MB marginal
    procs            # +6.2 MB marginal
    psmisc           # +711 KB marginal
    pwgen            # +42 KB marginal
    rclone           # +94 MB marginal (borderline, but useful for backups)
    ripgrep          # +6.4 MB marginal
    starship         # +13 MB marginal
    tealdeer         # +3.8 MB marginal
    terraform
    tmux             # +1.3 MB marginal
    tokei            # +6.0 MB marginal
    tre-command      # +2.7 MB marginal
    tree             # +95 KB marginal
    typst            # +43 MB marginal
    unzip            # +522 KB marginal
    usbutils         # +468 KB marginal
    wakeonlan        # +7.2 MB marginal
    wget             # +3.5 MB marginal
    yazi-unwrapped   # +24.5 MB marginal (vs 758 MB wrapped)
    yq-go            # +14 MB marginal
    zellij           # +48 MB marginal
  ];

  # --- Yazi preview dependencies (lightweight only) ---
  yaziPreviewDeps = with pkgs; [
    file # +22 KB marginal - MIME type detection
    # Heavy previewers moved to optional/large-packages.nix:
    # chafa, ffmpegthumbnailer, glow, poppler-utils
  ];

  # --- Development Toolchains (lightweight only) ---
  # Heavy toolchains moved to optional/large-packages.nix
  developmentToolchains = with pkgs; [
    gcc              # 0 bytes marginal (in baseline)
    gnumake          # +1.5 MB marginal
    meson            # +13 MB marginal
    nodejs_20        # 0 bytes marginal (in baseline)
    pkg-config       # +703 KB marginal
    portaudio        # +5.1 MB marginal
    (python3.withPackages (ps: [ ps.pipx ]))
    # Heavy toolchains in optional/large-packages.nix:
    # cargo, go, openjdk, bun, pnpm, yarn, cmake
  ];
in
{
  environment.systemPackages =
    cliPowerTools
    ++ yaziPreviewDeps
    ++ developmentToolchains;
}
