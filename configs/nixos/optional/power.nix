# Power management for always-on servers
{ ... }:

{
  # --- Disable Sleep/Hibernation ---
  # Keep SSH available by preventing sleep states
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowSuspendThenHibernate = "no";
    AllowHybridSleep = "no";
  };

  # --- Ignore Lid/Power Button ---
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandlePowerKey = "ignore";
    IdleAction = "ignore";
  };
}
