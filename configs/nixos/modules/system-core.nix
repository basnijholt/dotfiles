{ pkgs, ... }:

{
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
    RuntimeWatchdogSec = 300;
  };

  # 5.  Tell the NVIDIA driver *not* to preserve (and thus remap) VRAM
  #     across suspend / VT switches – that’s where the bug might be triggered.
  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=0" ];

  # --- Block every real sleep state ---
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
  '';

  # --- System Compatibility ---
  programs.nix-ld.enable = true; # Run non-nix executables (e.g., micromamba)

  # --- Audio ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # This provides PulseAudio compatibility
    jack.enable = true; # For compatibility with JACK applications
  };

  # --- Shell & Terminal ---
  programs.zsh.enable = true;
  programs.direnv.enable = true;

  # --- Fonts ---
  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    nerd-fonts.jetbrains-mono
  ];
}
