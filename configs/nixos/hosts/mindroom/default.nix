{ lib, pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: mindroom is a lightweight development container
    ../../optional/git-repo-checkouts.nix
    ../../optional/virtualization.nix
    ../../optional/mindroom-runtime-services.nix
    ../../optional/agent-env.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./secrets-config.nix
    ./mindroom.nix
    ./cinny.nix
    ./element.nix
    ./tuwunel.nix  # Local Matrix homeserver (MindRoom Tuwunel fork)
    ./caddy.nix
    ../../optional/openclaw/services.nix
  ];

  # Allow basnijholt passwordless sudo (for mindroom agent)
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # signal-cli for OpenClaw Signal channel
  environment.systemPackages = [ pkgs.signal-cli pkgs.ffmpeg-headless pkgs.chromium ];

  nixpkgs.config.permittedInsecurePackages = lib.mkAfter [
    "openclaw-2026.4.21"
    "openclaw-2026.5.7"
    "openclaw-2026.5.12"
  ];

  # libstdc++.so.6 for Python packages (numpy, qdrant-client, chromadb)
  # that link against it. Without this, uv run / pytest fail with import errors.
  environment.variables.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";

  # Disable comin on this host — we deploy manually via nixos-rebuild switch.
  services.comin.enable = lib.mkForce false;
}
