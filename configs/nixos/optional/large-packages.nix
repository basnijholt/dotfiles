# Large packages - opt-in for hosts that need them
#
# These packages have high marginal cost (>50MB unique dependencies).
# Based on analysis from scripts/nix/package-marginal-cost.py
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- Cloud CLIs (~1GB+ each) ---
    azure-cli         # +1.0 GB marginal
    google-cloud-sdk  # +690 MB marginal

    # --- Heavy Dev Tools ---
    cargo             # +1.5 GB marginal (Rust toolchain)
    go                # +192 MB marginal (Go toolchain)
    openjdk           # +695 MB marginal (JVM)
    pnpm              # +108 MB marginal
    yarn              # +98 MB marginal
    cmake             # +62 MB marginal

    # --- Media/Terminal Recording ---
    vhs               # +1.3 GB marginal (Go + Chromium for terminal recording)

    # --- Browsers ---
    chromium          # +1.2 GB marginal

    # --- Kubernetes ---
    k9s               # +167 MB marginal

    # --- Yazi preview deps (heavy) ---
    ffmpegthumbnailer # +166 MB marginal (video thumbnails)
    imagemagick       # +116 MB marginal (image manipulation)
    poppler-utils     # +39 MB marginal (PDF preview)
    glow              # +17 MB marginal (Markdown preview)
    chafa             # +77 MB marginal (image preview)
  ];
}
