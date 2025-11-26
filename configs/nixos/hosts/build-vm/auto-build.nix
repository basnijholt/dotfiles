# Automatic nix build service for caching
{ config, pkgs, ... }:

{
  # --- Auto-Build Service ---
  systemd.services.nix-auto-build = {
    description = "Build and cache NixOS configurations";
    path = with pkgs; [ git nix openssh ];
    script = ''
      set -euo pipefail

      DOTFILES="/var/lib/nix-auto-build/dotfiles"

      # Clone or update dotfiles
      if [ ! -d "$DOTFILES" ]; then
        git clone https://github.com/basnijholt/dotfiles.git "$DOTFILES"
      else
        cd "$DOTFILES"
        git fetch origin
        git reset --hard origin/main
      fi

      cd "$DOTFILES/configs/nixos"

      # Update flake inputs
      nix flake update

      # Build all host configurations
      for host in nixos nuc hp; do
        echo "Building $host..."
        nix build .#nixosConfigurations.$host.config.system.build.toplevel \
          --no-link \
          --print-out-paths \
          || echo "Warning: $host build failed, continuing..."
      done

      echo "All builds completed at $(date)"
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      # Generous timeout for CUDA builds
      TimeoutStartSec = "4h";
    };
  };

  # --- Daily Timer ---
  systemd.timers.nix-auto-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Ensure build directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/nix-auto-build 0755 root root -"
  ];
}
