# Power management for always-on servers
{ ... }:

{
  # --- Disable Sleep/Hibernation ---
  # Keep SSH available by preventing sleep states
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
  '';

  # --- Ignore Lid/Power Button ---
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandlePowerKey = "ignore";
    IdleAction = "ignore";
  };
}
