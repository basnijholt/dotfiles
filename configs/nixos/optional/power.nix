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
  # Using extraConfig for compatibility with older nixpkgs (nixos-raspberrypi)
  services.logind.extraConfig = ''
    HandleLidSwitch=ignore
    HandlePowerKey=ignore
    IdleAction=ignore
  '';
}
