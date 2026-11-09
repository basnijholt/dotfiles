{ ... }:
{
  # Never sleep, and reboot itself if the kernel hangs
  power.sleep.computer = "never";
  # Keep the virtual screen awake too, so screenshots over SSH aren't black.
  # With the lid closed no physical panel is lit.
  power.sleep.display = "never";
  power.restartAfterFreeze = true;
  # Always on the charger, so keep the battery from sitting at 100%
  local.chargeLimit = 80;

  # BetterDisplay keeps a virtual screen connected, so Screen Sharing still has
  # a display to show when the lid is closed and the internal panel is off.
  # It is a GUI app, so after a reboot it only starts once someone logs in.
  homebrew.casks = [ "betterdisplay" ];
  launchd.user.agents.betterdisplay = {
    command = "/usr/bin/open -a BetterDisplay";
    serviceConfig.RunAtLoad = true;
  };

  # Tailscale's GUI app only runs inside a login session, and its own
  # "Launch at login" setting can be off. Open it at login so the Mac comes
  # back on the tailnet after a reboot without anyone opening it by hand.
  launchd.user.agents.tailscale = {
    command = "/usr/bin/open -a Tailscale";
    serviceConfig.RunAtLoad = true;
  };

  # A macOS update restarts the Mac, and then Tailscale and the user agents
  # stay down until someone logs in (FileVault rules out auto-login). Install
  # macOS updates by hand instead.
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  system.activationScripts.postActivation.text = ''
    # power.sleep.computer only covers idle sleep; closing the lid still sleeps without this.
    # This is global, so on battery it also stays up and rides out short power cuts.
    pmset -a disablesleep 1
  '';

  # Not declarative: Screen Sharing has to be switched on once in System
  # Settings > General > Sharing. Starting it with launchctl opens port 5900,
  # but macOS then rejects clients with "Screen Sharing is not permitted".
  # BetterDisplay's first launch also needs a click on the Gatekeeper prompt.
}
