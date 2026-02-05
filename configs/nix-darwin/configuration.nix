{ pkgs, ... }:
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
    cups # lp command for network printing
    devbox
    nixpkgs-fmt
  ];

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
