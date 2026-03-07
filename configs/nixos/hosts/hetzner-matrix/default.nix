# Hetzner Cloud VPS - MindRoom Tuwunel Matrix homeserver
#
# Public Matrix homeserver for MindRoom users. Users run MindRoom locally
# and connect to this server.
{ lib, pkgs, ... }:

{
  imports = [
    ../../optional/zfs-auto-snapshot.nix
    ./networking.nix
    ./local_mindroom_provisioning_service.nix
    ./git-repo-checkouts.nix

    # Service-focused modules
    ./secrets-config.nix
    ./tuwunel.nix
    ./caddy.nix
    ./cinny.nix
    ./provisioning.nix
    ./sygnal.nix
    ./signal.nix
    ./whatsapp.nix
    ./telegram.nix
  ];

  # ── General server config ──────────────────────────────────────────

  # Packages needed for release pin updates and operational debugging.
  environment.systemPackages = with pkgs; [ git curl jq ffmpeg-headless ];

  # Disable services not needed on a Matrix server
  services.fwupd.enable = lib.mkForce false;
  services.syncthing.enable = lib.mkForce false;

  # SSH config
  services.openssh.settings.UseDns = lib.mkForce false;
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # DNS (not on local LAN)
  networking.nameservers = lib.mkForce [ "1.1.1.1" "8.8.8.8" "100.100.100.100" ];

  # Nix caches (no local cache reachable)
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];

  # Required by nixpkgs' current mautrix-signal package.
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  # Limit build parallelism on small VPS
  nix.settings.max-jobs = 2;
  nix.settings.cores = 2;

  # Zram swap for builds
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # ZFS
  networking.hostId = "a1b2c3d4"; # Generate with: head -c4 /dev/urandom | od -A none -t x4 | tr -d ' '

  # Tailscale for management
  services.tailscale.enable = lib.mkForce true;
}
