{ pkgs, ... }:

{
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
}
