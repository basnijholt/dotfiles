# Debug-freeze helpers (watchdog, hung-task panic, persistent journal)
{ pkgs, ... }:

{
  # --- Persistent Journal ---
  services.journald.extraConfig = ''
    Storage=persistent
  '';

  # --- Kernel Watchdog ---
  # Panic after 60s total CPU stall + keep NMI watchdog on
  boot.kernel.sysctl = {
    "kernel.hung_task_timeout_secs" = 60;
    "kernel.watchdog" = 1;
  };

  # Load the AMD/X570 watchdog module so systemd can kick it
  boot.kernelModules = [ "sp5100_tco" ];

  # --- Systemd Watchdog ---
  # Hard-reboot if the watchdog isn't pinged for 300s
  systemd.settings.Manager = {
    RuntimeWatchdogSec = 300;
  };

  # --- NVIDIA VRAM Bug Workaround ---
  # Don't preserve VRAM across suspend/VT switches (bug trigger)
  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=0" ];
}
