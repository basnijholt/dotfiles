{ config, lib, pkgs, ... }:
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
    age # File encryption for App Store release credentials
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
  ]
  ++ lib.optionals config.privacyApps [
    qbittorrent # Torrent client; the Homebrew cask is disabled for failing Gatekeeper
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

      # Pinned Dock apps; replaces whatever is currently pinned
      persistent-apps = [
        { app = "/System/Applications/System Settings.app"; }
        { app = "/System/Applications/Messages.app"; }
        { app = "/System/Applications/Mail.app"; }
        { app = "/Applications/Brave Browser.app"; }
      ]
      # Chrome is only installed on hosts with privacyApps (see homebrew.nix)
      ++ lib.optionals config.privacyApps [
        { app = "/Applications/Google Chrome.app"; }
      ]
      ++ [
        { app = "/Applications/iTerm.app"; }
      ];
    };
    NSGlobalDomain = {
      # Tap to click, also for the login screen and other users
      "com.apple.mouse.tapBehavior" = 1;
    };
    trackpad = {
      # Enable tap to click
      Clicking = true;

      # Enable three finger drag
      TrackpadThreeFingerDrag = true;

      # Three-finger swipes take priority over three-finger drag, so move
      # them to four fingers (same as enabling the drag in System Settings)
      TrackpadThreeFingerHorizSwipeGesture = 0;
      TrackpadThreeFingerVertSwipeGesture = 0;
      TrackpadFourFingerHorizSwipeGesture = 2;
      TrackpadFourFingerVertSwipeGesture = 2;
    };
  };

  # Remote Login (SSH) on every Mac. On macOS 26 this also lets FileVault be
  # unlocked over SSH (from the LAN, Tailscale isn't up yet) after a reboot.
  services.openssh.enable = true;

  # Add ability to used TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Activation runs as root, so user defaults must be written as the primary user
  system.activationScripts.postActivation.text =
    let
      user = lib.escapeShellArg config.system.primaryUser;
      asUser = ''launchctl asuser "$(id -u -- ${user})" sudo --user=${user} --'';
    in
    ''
      # Configure Terminal.app to use Option as Meta key (for Alt+Arrow word navigation)
      ${asUser} defaults write com.apple.Terminal useOptionAsMetaKey -bool true

      # Per-host (ByHost) copy of the three-finger drag settings; System Settings
      # writes these too, but nix-darwin's trackpad options don't.
      # threeFingerDragGesture must be a bool (activateSettings ignores an int). Delete
      # first: writing true over an int 1 counts as unchanged and keeps the int.
      ${asUser} defaults -currentHost delete NSGlobalDomain com.apple.trackpad.threeFingerDragGesture 2>/dev/null || true
      ${asUser} defaults -currentHost write NSGlobalDomain com.apple.trackpad.threeFingerDragGesture -bool true
      ${asUser} defaults -currentHost write NSGlobalDomain com.apple.trackpad.threeFingerHorizSwipeGesture -int 0
      ${asUser} defaults -currentHost write NSGlobalDomain com.apple.trackpad.threeFingerVertSwipeGesture -int 0

      # Apply trackpad settings without logging out
      ${asUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
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
