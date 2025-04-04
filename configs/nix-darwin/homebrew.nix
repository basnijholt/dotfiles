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
      "asciinema"            # Terminal recorder
      "atuin"                # Shell history sync tool
      "autossh"              # Automatically restart SSH sessions
      "azure-cli"            # Microsoft Azure CLI
      "bat"                  # Better cat with syntax highlighting
      "blueutil"             # Bluetooth utility
      "brew-cask-completion" # Completion for brew cask
      "btop"                 # System monitor
      "cloudflared"          # Cloudflare tunnel
      "cmake"                # Build system
      "cmatrix"              # Matrix-style screen animation
      "cointop"              # Cryptocurrency tracker
      "coreutils"            # GNU core utilities
      "create-dmg"           # DMG creator
      "d2"                   # Diagram scripting language
      "eza"                  # ls alternative
      "findutils"            # GNU find utilities
      "fzf"                  # Fuzzy finder
      "gh"                   # GitHub CLI
      "gifsicle"             # GIF manipulator
      "git-extras"           # Additional git commands
      "git-lfs"              # Git large file storage
      "git-secret"           # Secret files in git
      "git"                  # Version control
      "gnu-sed"              # GNU version of sed
      "gnupg"                # GnuPG encryption
      "go"                   # Go programming language
      "graphviz"             # Graph visualization
      "grep"                 # GNU grep
      "htop"                # Process viewer
      "hugo"                # Static site generator
      "imagemagick"         # Image manipulation
      "iperf"               # Network bandwidth tool
      "iperf3"              # Network bandwidth tool v3
      "jq"                  # JSON processor
      "just"                # Command runner
      "keychain"            # SSH/GPG key manager
      "lazygit"             # Git TUI
      "lego"                # Let's Encrypt client
      "meson"               # Build system
      "micro"               # Terminal-based text editor
      "nano"                # Text editor
      "neovim"              # Text editor
      "nmap"                # Network scanner
      "node"                # JavaScript runtime
      "ollama"              # Ollama LLMs
      "openjdk"             # Java development kit
      "parallel"            # GNU parallel
      "pipx"                # Python app installer
      "pwgen"               # Password generator
      "rbenv"               # Ruby version manager
      "rclone"              # Cloud storage sync
      "rsync"               # File sync tool
      "ruby"                # Ruby programming language
      "rustup"              # Rust toolchain installer
      "ssh-copy-id"         # SSH public key installer
      "starship"            # Shell prompt
      "superfile"           # Modern terminal file manager
      "swiftformat"         # Swift code formatter
      "syncthing"           # File synchronization
      "tailscale"           # VPN service
      "tealdeer"            # Fast alternative to tldr
      "terraform"           # Infrastructure as code
      "tmux"                # Terminal multiplexer
      "tree"                # Directory listing
      "tre-command"         # Tree command, improved
      "typst"               # Markup-based typesetting
      "vsftpd"              # FTP server
      "wget"                # File downloader
      "yq"                  # YAML processor
      "zsh"                 # Shell
    ];

    # GUI Applications (Casks)
    casks = [
      "1password-cli"               # 1Password CLI
      "adobe-creative-cloud"        # Adobe suite
      "adobe-digital-editions"      # E-book reader
      "airflow"                     # Video transcoder
      "avast-security"              # Antivirus
      "balenaetcher"                # USB image writer
      "brave-browser"               # Web browser
      "calibre"                     # E-book manager
      "chromedriver"                # Chrome automation
      "cursor"                      # Cursor editor
      "cryptomator"                 # File encryption
      "cyberduck"                   # FTP client
      "db-browser-for-sqlite"       # SQLite browser
      "disk-inventory-x"            # Disk space visualizer
      "docker"                      # Container platform
      "dropbox"                     # Cloud storage
      "eqmac"                       # Audio equalizer
      "filebot"                     # File renamer
      "firefox"                     # Web browser
      "flux"                        # Screen color adjuster
      "font-fira-code"              # Programming font
      "font-fira-mono-nerd-font"    # Nerd font
      "foobar2000"                  # Music player
      "ghostty"                     # Terminal emulator
      "git-credential-manager"      # Git credential helper
      "github"                      # GitHub desktop
      "google-earth-pro"            # 3D earth viewer
      "handbrake"                   # Video transcoder
      "inkscape"                    # Vector graphics editor
      "istat-menus"                 # System monitor
      "iterm2"                      # Terminal emulator
      "jabref"                      # Reference manager
      "jordanbaird-ice"             # Window manager
      "karabiner-elements"          # Keyboard customizer
      "keepingyouawake"             # Prevent sleep
      "keyboard-maestro"            # Automation tool
      "licecap"                     # Screen recorder
      "lulu"                        # Firewall
      "lyx"                         # Document processor
      "macfuse"                     # Filesystem in userspace
      "mactracker"                  # Apple product database
      "mendeley"                    # Reference manager
      "microsoft-auto-update"       # Microsoft updater
      "microsoft-azure-storage-explorer" # Azure storage tool
      "microsoft-office"            # Office suite
      "microsoft-teams"             # Team communication
      "monitorcontrol"              # External display control
      "mounty"                      # NTFS mounter
      "mpv"                         # Media player
      "musicbrainz-picard"          # Music tagger
      "nordvpn"                     # VPN client
      "obs"                         # Streaming software
      "obsidian"                    # Note taking app
      "onyx"                        # System maintenance
      "proton-mail-bridge"          # ProtonMail bridge
      "qbittorrent"                 # Torrent client
      "qlvideo"                     # Video QuickLook
      "raycast"                     # Productivity tool
      "rectangle"                   # Window manager
      "rotki"                       # Portfolio tracker
      "sabnzbd"                     # Usenet client
      "scroll-reverser"             # Scroll direction control
      "selfcontrol"                 # Website blocker
      "signal"                      # Secure messenger
      "slack"                       # Slack chat
      "sloth"                       # Process monitor
      "spotify"                     # Music streaming
      "steam"                       # Game platform
      "submariner"                  # Subsonic music client
      "switchresx"                  # Display manager
      "syncthing"                   # File synchronization
      "teamviewer"                  # Remote control
      "telegram"                    # Messenger
      "tor-browser"                 # Private browser
      "tunnelblick"                 # OpenVPN client
      "unclack"                     # Mute keyboard sounds
      "universal-media-server"      # Media server
      "visual-studio-code"          # Code editor
      "vlc"                         # Media player
    ] ++ (if config.isPersonal then [
      "1password"                   # Password manager
      "google-chrome"               # Web browser
      "zoom"                        # Video conferencing
    ]
    else [
      "google-cloud-sdk"            # Google Cloud CLI
      "google-drive"                # Cloud storage
      "xquartz"                     # X11 server
      "klayout"                     # GDS Layout viewer
    ]);

    # Additional repositories
    taps = [
      "gromgit/fuse"         # For SSHFS
    ];
  };
}
