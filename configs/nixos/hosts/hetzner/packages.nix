# Minimal packages for Hetzner VPS
#
# Overrides common/packages.nix with a minimal set suitable for a Docker host.
# Based on marginal cost analysis (scripts/package-marginal-cost.py).
#
# Marginal cost = actual additional space when adding to a system.
{ lib, pkgs, ... }:

let
  # Essential tools - small marginal cost (<10MB each, except git)
  essentialTools = with pkgs; [
    coreutils # 0 bytes marginal (in base)
    gnused # 718 KB marginal
    gnugrep # 2.9 MB marginal
    jq # 1.2 MB marginal
    tree # 95 KB marginal
    lsof # 265 KB marginal
    psmisc # 711 KB marginal (killall, pstree)
    unzip # 2.4 MB marginal
    wget # 7.4 MB marginal
    tmux # 6.6 MB marginal
    htop # 6.1 MB marginal
    git # 276 MB marginal - large but essential
  ];

  # Nice-to-have tools - still small marginal cost
  niceToHave = with pkgs; [
    eza # 2.4 MB marginal (better ls)
    fzf # 9.1 MB marginal (fuzzy finder)
    ripgrep # 8.4 MB marginal (fast grep)
    duf # 5.1 MB marginal (disk usage)
    tealdeer # 3.8 MB marginal (tldr)
    procs # 6.2 MB marginal (better ps)
    file # 8.4 MB marginal (MIME detection)
    iperf3 # 2.4 MB marginal (network testing)
  ];

  # Medium cost but useful for Docker administration
  dockerTools = with pkgs; [
    lazydocker # 15 MB marginal (Docker TUI)
    yq-go # 16.8 MB marginal (YAML processor)
  ];
in
{
  # Override the common packages with our minimal set
  # Total marginal: ~370MB (mostly git at 276MB)
  environment.systemPackages = lib.mkForce (
    essentialTools ++ niceToHave ++ dockerTools
  );
}
