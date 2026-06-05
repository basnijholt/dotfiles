{ lib, pkgs, ... }:
{
  # Required for current nix-darwin
  nixpkgs.hostPlatform = "aarch64-darwin"; # for Apple Silicon

  # Enable experimental nix command and flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Add system packages
  environment.systemPackages = with pkgs; [
    colima # Container runtime for macOS
    lima # VM manager used by Colima; provides limactl for standalone VMs
    cups # lp command for network printing
    devbox
    docker # Docker CLI
    docker-buildx # Docker Buildx CLI plugin
    docker-compose # Docker Compose CLI plugin
    kubernetes-helm # Helm 3 Kubernetes package manager
    nixpkgs-fmt
    sops # Secrets editor
    cocoapods # required for Capacitor iOS builds (pod install)
  ];

  # Start the Docker-compatible Colima VM at login, without Docker Desktop.
  launchd.user.agents.colima = {
    command = "${pkgs.colima}/bin/colima start";
    serviceConfig = {
      RunAtLoad = true;
      EnvironmentVariables.PATH = "${lib.makeBinPath [
        pkgs.colima
        pkgs.docker
        pkgs.docker-buildx
        pkgs.docker-compose
      ]}:/usr/bin:/bin:/usr/sbin:/sbin";
    };
  };

  # Configure sudo password timeout (in minutes)
  security.sudo.extraConfig = ''
    # Set timeout to 1 hour (60 minutes)
    Defaults timestamp_timeout=60
  '';

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # Keyboard
  system.keyboard.enableKeyMapping = true;

  # Configure macOS system defaults
  system.defaults = {
    dock = {
      # Set the animation time modifier (0.0 = instant)
      autohide-time-modifier = 0.0;

      autohide = true; # automatically hide and show the dock
      show-recents = false; # don't show recent apps
      static-only = false; # show only running apps
    };
    trackpad = {
      # Enable tap to click
      Clicking = true;

      # Enable three finger drag
      TrackpadThreeFingerDrag = true;
    };
  };

  # Add ability to used TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Configure Terminal.app to use Option as Meta key (for Alt+Arrow word navigation)
  system.activationScripts.postActivation.text = ''
    defaults write com.apple.Terminal useOptionAsMetaKey -bool true
  '';

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh = {
    enable = true;
    enableCompletion = false; # Let oh-my-zsh handle compinit (saves ~300ms)
  };

  # Auto upgrade nix package and the daemon service.
  nix.package = pkgs.nix;

  nix.enable = false;
}
