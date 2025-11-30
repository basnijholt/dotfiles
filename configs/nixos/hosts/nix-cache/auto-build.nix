# Automatic nix build service for caching
{ config, pkgs, ... }:

{
  # --- Auto-Build Service ---
  systemd.services.nix-auto-build = {
    description = "Build and cache NixOS configurations";
    path = with pkgs; [ git nix openssh jq ];
    script = ''
      set -euo pipefail
      export NIX_REMOTE=daemon

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

      # Get the commit ID of the nixpkgs input (locked in flake.lock)
      COMMIT_ID=$(jq -r .nodes.nixpkgs.locked.rev flake.lock)

      # Build all host configurations (--cores 1 to limit memory usage)
      for host in pc nuc hp; do
        echo "Building $host..."
        if nix build .#nixosConfigurations.$host.config.system.build.toplevel \
          --out-link "/var/lib/nix-auto-build/result-$host" \
          --print-out-paths \
          --cores 1 \
          --max-jobs 1; then
            echo "$COMMIT_ID" > "/var/lib/nix-auto-build/$host.rev"
        else
            echo "Warning: $host build failed, continuing..."
        fi
      done

      echo "All builds completed at $(date)"
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      # Generous timeout for CUDA builds
      TimeoutStartSec = "3d";
    };
  };

  # --- Daily Timer ---
  systemd.timers.nix-auto-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Ensure build directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/nix-auto-build 0755 root root -"
  ];
}
