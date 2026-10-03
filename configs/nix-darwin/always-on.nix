{ ... }:
{
  # Never sleep while on AC power and reboot itself if the kernel hangs
  power.sleep.computer = "never";
  # Keep the virtual screen awake too, so screenshots over SSH aren't black.
  # With the lid closed no physical panel is lit.
  power.sleep.display = "never";
  power.restartAfterFreeze = true;

  # Remote Login. On macOS 26 this also lets FileVault be unlocked over SSH
  # (from the LAN, Tailscale isn't up yet) after a reboot.
  services.openssh.enable = true;

  # BetterDisplay keeps a virtual screen connected, so Screen Sharing still has
  # a display to show when the lid is closed and the internal panel is off
  homebrew.casks = [ "betterdisplay" ];
  launchd.user.agents.betterdisplay = {
    command = "/usr/bin/open -a BetterDisplay";
    serviceConfig.RunAtLoad = true;
  };

  system.activationScripts.postActivation.text = ''
    # power.sleep.computer only covers idle sleep; closing the lid still sleeps without this
    pmset -a disablesleep 1

    # Screen Sharing (VNC on port 5900)
    if ! launchctl print system/com.apple.screensharing &> /dev/null; then
      launchctl enable system/com.apple.screensharing
      launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist
    fi
  '';
}
