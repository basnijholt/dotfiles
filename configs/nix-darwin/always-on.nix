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

  # Remote Login. On macOS 26 this also lets FileVault be unlocked over SSH
  # (from the LAN, Tailscale isn't up yet) after a reboot.
  services.openssh.enable = true;

  # BetterDisplay keeps a virtual screen connected, so Screen Sharing still has
  # a display to show when the lid is closed and the internal panel is off.
  # It is a GUI app, so after a reboot it only starts once someone logs in.
  homebrew.casks = [ "betterdisplay" ];
  launchd.user.agents.betterdisplay = {
    command = "/usr/bin/open -a BetterDisplay";
    serviceConfig.RunAtLoad = true;
  };

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
