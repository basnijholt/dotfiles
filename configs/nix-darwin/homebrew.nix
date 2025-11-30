{ config, pkgs, ... }:

{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    # CLI Tools (Part 1)
    brews = [
      "asciinema" # Terminal recorder
      "atuin" # Shell history sync tool
      "autossh" # Automatically restart SSH sessions
      "azure-cli" # Microsoft Azure CLI
      "bat" # Better cat with syntax highlighting
      "blueutil" # Bluetooth utility
      "brew-cask-completion" # Completion for brew cask
      "btop" # System monitor
      "cloudflared" # Cloudflare tunnel
      "cmake" # Build system
      "cmatrix" # Matrix-style screen animation
      "cointop" # Cryptocurrency tracker
      "coreutils" # GNU core utilities
      "create-dmg" # DMG creator
      "d2" # Diagram scripting language
      "eza" # ls alternative
      "ffmpeg" # Multimedia framework
      "findutils" # GNU find utilities
      "fzf" # Fuzzy finder
      "gh" # GitHub CLI
      "gifsicle" # GIF manipulator
      "git-extras" # Additional git commands
      "git-lfs" # Git large file storage
      "git-secret" # Secret files in git
      "git" # Version control
      "gnu-sed" # GNU version of sed
      "gnupg" # GnuPG encryption
      "go" # Go programming language
      "graphviz" # Graph visualization
      "grep" # GNU grep
      "htop" # Process viewer
      "hugo" # Static site generator
      "imagemagick" # Image manipulation
      "incus" # Container hypervisor
      "iperf" # Network bandwidth tool
      "iperf3" # Network bandwidth tool v3
      "jq" # JSON processor
      "just" # Command runner
      "keychain" # SSH/GPG key manager
      "lazygit" # Git TUI
      "lego" # Let's Encrypt client
      "meson" # Build system
      "micro" # Terminal-based text editor
      "mosh" # Mobile shell
      "nano" # Text editor
      "neovim" # Text editor
      "nmap" # Network scanner
      "node" # JavaScript runtime
      "ollama" # Ollama LLMs
      "opencode" # Open source coding agent CLI
      "openjdk" # Java development kit
      "pandoc" # Document converter
      "parallel" # GNU parallel
      "pipx" # Python app installer
      "portaudio" # Audio I/O library
      "pwgen" # Password generator
      "rbenv" # Ruby version manager
      "rclone" # Cloud storage sync
      "rsync" # File sync tool
      "ruby" # Ruby programming language
      "rustup" # Rust toolchain installer
      "skhd-zig" # Hotkey daemon
      "ssh-copy-id" # SSH public key installer
      "starship" # Shell prompt
      "superfile" # Modern terminal file manager
      "swiftformat" # Swift code formatter
      "tealdeer" # Fast alternative to tldr
      "terminal-notifier" # macOS notification tool
      "terraform" # Infrastructure as code
      "tmux" # Terminal multiplexer
      "tre-command" # Tree command, improved
      "tree" # Directory listing
      "typst" # Markup-based typesetting
      "vsftpd" # FTP server
      "wget" # File downloader
      "yq" # YAML processor
      "zsh" # Shell
    ] ++ (
      if config.isPersonal then
        []
      else
        [
          "llvm@17" # LLVM toolchain
          "protobuf" # Protocol Buffers
          "slackdump" # Slack archiver
        ]
    );

    # GUI Applications (Casks)
    casks = [
      "1password-cli" # 1Password CLI
      "adobe-creative-cloud" # Adobe suite
      "adobe-digital-editions" # E-book reader
      "airflow" # Video transcoder
      "avast-security" # Antivirus
      "balenaetcher" # USB image writer
      "block-goose" # open source AI agent
      "brave-browser" # Web browser
      "calibre" # E-book manager
      "chromedriver" # Chrome automation
      "cryptomator" # File encryption
      "cursor" # Cursor editor
      "cyberduck" # FTP client
      "db-browser-for-sqlite" # SQLite browser
      "disk-inventory-x" # Disk space visualizer
      "docker-desktop" # Container platform
      "dropbox" # Cloud storage
      "eqmac" # Audio equalizer
      "filebot" # File renamer
      "firefox" # Web browser
      "flux-app" # Screen color adjuster
      "font-fira-code" # Programming font
      "font-fira-mono-nerd-font" # Nerd font
      "foobar2000" # Music player
      "ghostty" # Terminal emulator
      "git-credential-manager" # Git credential helper
      "github" # GitHub desktop
      "google-earth-pro" # 3D earth viewer
      "handbrake-app" # Video transcoder
      "inkscape" # Vector graphics editor
      "istat-menus" # System monitor
      "iterm2" # Terminal emulator
      "jabref" # Reference manager
      "jordanbaird-ice" # Window manager
      "karabiner-elements" # Keyboard customizer
      "keepingyouawake" # Prevent sleep
      "keyboard-maestro" # Automation tool
      "licecap" # Screen recorder
      "lulu" # Firewall
      "lyx" # Document processor
      "macfuse" # Filesystem in userspace
      "mactracker" # Apple product database
      "mendeley" # Reference manager
      "microsoft-auto-update" # Microsoft updater
      "microsoft-azure-storage-explorer" # Azure storage tool
      "microsoft-office" # Office suite
      "microsoft-teams" # Team communication
      "monitorcontrol" # External display control
      "mounty" # NTFS mounter
      "musicbrainz-picard" # Music tagger
      "obs" # Streaming software
      "obsidian" # Note taking app
      "onyx" # System maintenance
      "proton-mail-bridge" # ProtonMail bridge
      "qbittorrent" # Torrent client
      "qlvideo" # Video QuickLook
      "raycast" # Productivity tool
      "rectangle" # Window manager
      "rotki" # Portfolio tracker
      "sabnzbd" # Usenet client
      "scroll-reverser" # Scroll direction control
      "selfcontrol" # Website blocker
      "signal" # Secure messenger
      "slack" # Slack chat
      "sloth" # Process monitor
      "spotify" # Music streaming
      "steam" # Game platform
      "stolendata-mpv" # Media player
      "submariner" # Subsonic music client
      "switchresx" # Display manager
      "syncthing-app" # File synchronization
      "teamviewer" # Remote control
      "telegram" # Messenger
      "tor-browser" # Private browser
      "tunnelblick" # OpenVPN client
      "unclack" # Mute keyboard sounds
      "universal-media-server" # Media server
      "visual-studio-code" # Code editor
      "vlc" # Media player
      "wezterm" # Terminal emulator
    ]
    ++ (
      if config.isPersonal then
        [
          "1password" # Password manager
          "google-chrome" # Web browser
          "mullvad-vpn" # VPN client
          "nordvpn" # VPN client
          "tailscale" # VPN service
          "zoom" # Video conferencing
        ]
      else
        [
          "gcloud-cli" # Google Cloud CLI
          "google-drive" # Cloud storage
          "klayout" # GDS Layout viewer
          "xquartz" # X11 server
        ]
    );

    # Additional repositories
    taps = [
      "gromgit/fuse" # For SSHFS
      "jackielii/tap" # for skhd-zig
    ];
  };
}
