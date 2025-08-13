# /etc/nixos/configuration.nix
# NixOS -- basnijholt/dotfiles

{ config, pkgs, ... }:

let

  ###############################################################################
  # NVIDIA Wayland VRAM workaround (driver ≥ R565)
  #
  # • Fresh login → Hyprland grabs ~3.2 GiB of GPU memory on a 5 K screen.
  # • Adding a profile that targets the real ELF
  #     procname = ".Hyprland‑wrapped"
  #   caps the driver’s free‑buffer pool → usage drops to ~800 MiB.
  #
  # Upstream references:
  #   – https://github.com/NVIDIA/egl-wayland/issues/126#issuecomment-2379945259
  #   – https://github.com/hyprwm/Hyprland/issues/7704#issuecomment-2639212608
  ###############################################################################
  limitFreeBufferProfile = builtins.toJSON {
    rules = [
      {
        pattern = {
          feature = "procname";
          matches = ".Hyprland-wrapped";
        };
        profile = "Limit Free Buffer Pool On Wayland Compositors";
      }
      {
        pattern = {
          feature = "procname";
          matches = "gnome-shell";
        };
        profile = "Limit Free Buffer Pool On Wayland Compositors";
      }
    ];
    profiles = [
      {
        name = "Limit Free Buffer Pool On Wayland Compositors";
        settings = [
          {
            key = "GLVidHeapReuseRatio";
            value = 0;
          }
        ];
      }
    ];
  };
in
{
  imports = [
    ./kinto.nix
    ./hardware-configuration.nix
  ];

  # ===================================
  # Boot Configuration
  # ===================================
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    useOSProber = true;
    device = "nodev";
    memtest86.enable = true;
    theme = pkgs.sleek-grub-theme.override {
      withStyle = "orange";
      withBanner = "Welcome Bas!";
    };
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # ===================================
  # Hardware Configuration
  # ===================================
  # --- NVIDIA Graphics ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
  hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # --- Swap ---
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

  # --- Ensure WiFi stays up ---
  networking.networkmanager.settings."connection" = {
    "wifi.powersave" = 2;
  };

  # --- Audio ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # This provides PulseAudio compatibility
    jack.enable = true; # For compatibility with JACK applications
  };

  # --- Bluetooth & Xbox Controller ---
  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # Automatically powers on Bluetooth after booting.
    settings.General = {
      experimental = true; # Show battery levels
      # Helps controllers reconnect more reliably.
      JustWorksRepairing = "always";
      FastConnectable = true;
    };
  };

  # Enable the advanced driver for modern Xbox wireless controllers.
  # This is crucial for proper functionality in Steam and other games.
  hardware.xpadneo.enable = true;

  # This kernel option is a common fix for Bluetooth controller issues on Linux.
  # It disables Enhanced Re-Transmission Mode, which can cause lag or disconnects.
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=Y
  '';

  # ===================================
  # System Configuration
  # ===================================
  # --- Core Settings ---
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  ###############################################################################
  # Debug‑freeze helpers (watchdog, hung‑task panic, persistent journal)
  ###############################################################################

  # 1.  Keep logs after reboot
  services.journald.extraConfig = ''
    Storage=persistent
  '';

  # 2.  Panic after 60 s total CPU stall + keep NMI watchdog on
  boot.kernel.sysctl = {
    "kernel.hung_task_timeout_secs" = 60;
    "kernel.watchdog" = 1;
  };

  # 3.  Load the AMD/X570 watchdog module so systemd can kick it
  boot.kernelModules = [ "sp5100_tco" ];

  # 4.  Tell systemd to hard‑reboot if the watchdog isn’t pinged for 120 s
  systemd.settings.Manager = {
    RuntimeWatchdogSec = 120;
  };

  # 5.  Tell the NVIDIA driver *not* to preserve (and thus remap) VRAM
  #     across suspend / VT switches – that’s where the bug might be triggered.
  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=0" ];

  # --- Hostname & Networking ---
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [
    10200 # Wyoming Piper
    10300 # Wyoming Faster Whisper - English
    10301 # Wyoming Faster Whisper - Dutch
    10400 # Wyoming OpenWakeword
    8880 # Kokoro TTS
    6333 # Qdrant
    61337 # Agent CLI server
    8008 # Synapse
    8009 # Synapse
    8448 # Synapse
    9292 # llama-swap proxy
  ];

  # --- Nix Package Manager Settings ---
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  # --- Nixpkgs Configuration ---
  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
    packageOverrides = pkgs: {
      # Override ollama to version 0.11.0 with auto-calculated hash
      ollama = pkgs.ollama.overrideAttrs (oldAttrs: rec {
        version = "0.11.4";
        src = pkgs.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          rev = "v${version}";
          hash = "sha256-po7BxJAj9eOpOaXsLDmw6/1RyjXPtXza0YUv0pVojZ0=";
        };
        # Disable tests due to flaky TestConvertAdapter
        doCheck = false;
      });

      # Override llama-cpp to latest version b6150 with CUDA support
      llama-cpp =
        (pkgs.llama-cpp.override {
          cudaSupport = true;
          rocmSupport = false;
          metalSupport = false;
        }).overrideAttrs
          (oldAttrs: rec {
            version = "6150";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-oClTUbwVagHb08LmUsOJErr4lEVYSyqfU5nGKTlsH+o=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
          });

      # llama-swap from GitHub releases
      llama-swap = pkgs.runCommand "llama-swap" { } ''
        mkdir -p $out/bin
        tar -xzf ${
          pkgs.fetchurl {
            url = "https://github.com/mostlygeek/llama-swap/releases/download/v150/llama-swap_150_linux_amd64.tar.gz";
            hash = "sha256-NKXN2zM8qjBYBgkhQ78obUiMZCFNcW2av3fJNJrFm2Y=";
          }
        } -C $out/bin
        chmod +x $out/bin/llama-swap
      '';
    };
  };

  # --- Fonts ---
  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    nerd-fonts.jetbrains-mono
  ];

  # --- Block every real sleep state ---
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
  '';

  # ===================================
  # User Configuration
  # ===================================
  users.users.basnijholt = {
    isNormalUser = true;
    description = "Bas Nijholt";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "libvirtd"
    ];
    shell = pkgs.zsh;
  };

  # ===================================
  # Desktop Environment
  # ===================================
  # --- X11 & Display Managers ---
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  programs.dconf.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # --- Hyprland ---
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = "gtk";
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
      };
    };
  };

  # ===================================
  # System Programs & Services
  # ===================================
  # --- Shell & Terminal ---
  programs.zsh.enable = true;
  programs.direnv.enable = true;

  # --- SSH ---
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      UseDns = true;
      X11Forwarding = true;
    };
  };

  # --- Security & Authentication ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
  programs._1password.enable = true;
  programs._1password-gui.enable = true;
  programs._1password-gui.polkitPolicyOwners = [ "basnijholt" ];

  # --- Virtualization ---
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # --- AI & Machine Learning ---
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    host = "0.0.0.0";
    openFirewall = true;
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "1h";
    };
  };

  # --- llama-swap service ---
  # Transparent proxy for automatic model swapping with llama.cpp

  # GPT-OSS chat template directly from HuggingFace
  environment.etc."llama-templates/openai-gpt-oss-20b.jinja".source = pkgs.fetchurl {
    url = "https://huggingface.co/openai/gpt-oss-20b/resolve/main/chat_template.jinja";
    sha256 = "sha256-pMmRnLvUrN1RzP/iLaBJJksbc+WQVfpYgRqZ7718gUY=";
  };

  environment.etc."llama-swap/config.yaml".text = ''
    # llama-swap configuration
    # This config uses llama.cpp's server to serve models on demand

    models:
      # Small models
      "qwen2.5-0.5b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo bartowski/Qwen2.5-0.5B-Instruct-GGUF
          --hf-file Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 8192
          --n-gpu-layers 99
          --main-gpu 0

      "smollm2-135m":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/SmolLM2-135M-Instruct-GGUF
          --hf-file SmolLM2-135M-Instruct-Q8_0.gguf
          --port ''${PORT}
          --ctx-size 4096
          --n-gpu-layers 99
          --main-gpu 0

      # Coding models
      "qwen3-coder-30b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF
          --hf-file Qwen3-Coder-30B-A3B-q4_k_m.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0
          --flash-attn

      "devstral-24b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo mistralai/Devstral-Small-2507_gguf
          --hf-file Devstral-Small-2507-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0
          --flash-attn

      # Large reasoning models
      "dolphin-mistral-24b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo bartowski/cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-GGUF
          --hf-file cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0
          --flash-attn

      "qwen3-thinking-4b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/Qwen3-4B-Thinking-2507-GGUF
          --hf-file Qwen3-4B-Thinking-2507-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0

      "gpt-oss-20b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/gpt-oss-20b-GGUF
          --hf-file gpt-oss-20b-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0
          --jinja
          --chat-template-file /etc/llama-templates/openai-gpt-oss-20b.jinja
          --flash-attn
          --cont-batching
          --no-mmap
          --threads 12
          --parallel 2

    healthCheckTimeout: 600  # 10 minutes for large model download + loading

    # TTL keeps models in memory for specified seconds after last use
    ttl: 3600  # Keep models loaded for 1 hour (like OLLAMA_KEEP_ALIVE)

    # Groups allow running multiple models simultaneously
    # Uncomment and adjust based on your VRAM (24GB RTX 3090)
    # groups:
    #   small:  # ~2-4GB VRAM total
    #     - "qwen2.5-0.5b"
    #     - "smollm2-135m"
    #     - "qwen3-thinking-4b"
    #   coding:  # Can't run both together (~15-20GB each)
    #     - "qwen3-coder-30b"
    #     - "devstral-small-22b"
    #   large:  # ~13-15GB VRAM each
    #     - "dolphin-mistral-24b"
    #     - "gpt-oss-20b"
  '';

  systemd.services.llama-swap = {
    description = "llama-swap - OpenAI compatible proxy with automatic model swapping";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "basnijholt";
      Group = "users";
      ExecStart = "${pkgs.llama-swap}/bin/llama-swap --config /etc/llama-swap/config.yaml --listen 0.0.0.0:9292 --watch-config";
      Restart = "always";
      RestartSec = 10;

      # Environment for CUDA support
      Environment = [
        "PATH=/run/current-system/sw/bin"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
      ];

      # Environment needs access to cache directories for model downloads
      # Simplified security settings to avoid namespace issues
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
  services.wyoming.faster-whisper = {
    servers.english = {
      enable = true;
      model = "large-v3";
      language = "en";
      device = "cuda";
      uri = "tcp://0.0.0.0:10300";
    };
    servers.dutch = {
      enable = false;
      model = "large-v3";
      language = "nl";
      device = "cuda";
      uri = "tcp://0.0.0.0:10301";
    };
  };
  services.wyoming.piper.servers.yoda = {
    enable = true;
    voice = "en-us-ryan-high";
    uri = "tcp://0.0.0.0:10200";
  };
  services.wyoming.openwakeword = {
    enable = true;
    preloadModels = [
      "alexa"
      "hey_jarvis"
      "ok_nabu"
    ];
    uri = "tcp://0.0.0.0:10400";
  };
  services.qdrant = {
    enable = true;
    settings = {
      storage = {
        storage_path = "/var/lib/qdrant/storage";
        snapshots_path = "/var/lib/qdrant/snapshots";
      };
      service = {
        host = "0.0.0.0";
        http_port = 6333;
      };
      telemetry_disabled = true;
    };
  };

  # --- Other Services ---
  programs.steam.enable = true;
  services.fwupd.enable = true;
  services.syncthing.enable = true;
  services.tailscale.enable = true;
  services.printing.enable = true;
  programs.thunderbird.enable = true;

  # --- SLURM High-Performance Computing ---
  # One-time setup: Create munge key with:
  # sudo mkdir -p /etc/munge && sudo dd if=/dev/urandom bs=1 count=1024 | sudo tee /etc/munge/munge.key > /dev/null
  # Then: sudo nixos-rebuild switch
  #
  # Test with: sinfo, squeue, srun hostname

  # Create required directories with proper permissions
  systemd.tmpfiles.rules = [
    "d /etc/munge 0700 munge munge -"
    "d /var/spool/slurm 0755 slurm slurm -"
    "d /var/spool/slurmd 0755 slurm slurm -"
    "Z /etc/munge/munge.key 0400 munge munge -"
  ];

  services.munge = {
    enable = true;
    password = "/etc/munge/munge.key";
  };

  services.slurm = {
    server.enable = true;
    client.enable = true;
    clusterName = "homelab";
    controlMachine = "nixos";
    nodeName = [
      "nixos CPUs=24 State=UNKNOWN" # Adjust CPUs to match your system
    ];
    partitionName = [
      "cpu Nodes=nixos Default=YES MaxTime=INFINITE State=UP"
    ];
    extraConfig = ''
      AccountingStorageType=accounting_storage/none
      JobAcctGatherType=jobacct_gather/none
      ProctrackType=proctrack/cgroup
      ReturnToService=1
      SlurmdSpoolDir=/var/spool/slurmd
    '';
  };

  # Sunshine notes: Had to change the `https://discourse.nixos.org/t/give-user-cap-sys-admin-p-capabillity/62611/2`
  # in Sunshine Steam App `sudo -u myuser setsid steam steam://open/bigpicture` as Detached Command
  # then in Steam Settings: Interface -> "Enable GPU accelerated ..." but disable "hardware video decoding"
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # --- System Compatibility ---
  programs.nix-ld.enable = true; # Run non-nix executables (e.g., micromamba)

  # ===================================
  # System Packages
  # ===================================
  environment.systemPackages = with pkgs; [
    # GUI Applications
    _1password-gui
    _1password-cli
    brave
    code-cursor
    cryptomator
    docker
    dropbox
    filebot
    firefox
    google-cloud-sdk
    handbrake
    inkscape
    moonlight-qt
    mullvad-vpn
    obs-studio
    obsidian
    qbittorrent
    signal-desktop
    slack
    spotify
    telegram-desktop
    tor-browser-bundle-bin
    vlc
    vscode

    # CLI Power Tools & Utilities
    asciinema
    atuin
    azure-cli
    bat
    btop
    claude-code
    coreutils
    duf
    eza
    fastfetch
    fzf
    gemini-cli
    gh
    git
    git-lfs
    git-secret
    gnugrep
    gnupg
    gnused
    htop
    iperf3
    jq
    just
    keyd
    lazygit
    libnotify
    llama-cpp
    lm_sensors
    lsof
    micro
    neovim
    nixfmt-rfc-style
    nmap
    nvtopPackages.full
    ollama
    parallel
    pavucontrol
    pinentry-gnome3
    psmisc # For killall
    pulseaudio
    pwgen
    rclone
    ripgrep
    starship
    tealdeer
    terraform
    tmux
    tree
    typst
    wget
    xclip
    xsel
    yq-go
    zellij

    # Development Toolchains
    cargo
    cmake
    cudatoolkit
    gcc
    go
    gnumake
    meson
    nodejs_20
    openjdk
    pkg-config
    pnpm
    portaudio
    (python3.withPackages (ps: [ ps.pipx ]))
    rust-analyzer
    winetricks

    # Terminals & Linux-native Alternatives
    alacritty
    baobab
    flameshot
    ghostty
    kitty
    opensnitch

    # Hyprland Essentials
    polkit_gnome
    waybar # Status bar (most popular by far)
    hyprpanel # Status bar (alternative to waybar)
    wofi # Application launcher (simpler than rofi)
    mako # Notification daemon (Wayland-native)
    swww # Wallpaper daemon (smooth transitions)
    wl-clipboard # Clipboard manager (copy/paste support)
    wl-clip-persist # Clipboard persistence
    cliphist # Clipboard history
    hyprlock # Screen locker
    hyprpicker # Color picker
    hyprshot # Screenshot tool (Hyprland-specific)
  ];

  # ===================================
  # Environment Variables
  # ===================================
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # covers all nixpkgs-wrapped Chromium/Electron apps
    ELECTRON_OZONE_PLATFORM_HINT = "auto"; # covers Flatpak/AppImage/binaries that bypass the wrapper
  };

  # NVIDIA VRAM leak workaround, see comment at top.
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    limitFreeBufferProfile;

  # ===================================
  # Home Manager Configuration
  # ===================================
  home-manager.users.basnijholt =
    { pkgs, config, ... }:
    {
      home.stateVersion = "25.05";

      # --- Mechabar Dependencies ---
      home.packages = with pkgs; [
        bluetui
        bluez
        brightnessctl
        pipewire
        wireplumber
        rofi-wayland
      ];
    };

  # The system state version is critical and should match the installed NixOS release.
  system.stateVersion = "25.05";
}
