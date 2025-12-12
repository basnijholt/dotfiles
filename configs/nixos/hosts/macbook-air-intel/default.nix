{ pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: Intel MacBook Air
    ../../optional/virtualization.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "ignore";
    extraConfig = ''
      IdleAction=suspend
      IdleActionSec=30m
    '';
  };

  # Prevent idle suspend when on AC power
  systemd.services.ac-idle-suppress = {
    description = "Suppress idle suspend when on AC power";
    wantedBy = [ "multi-user.target" ];
    script = ''
      INHIBITOR_PID=""
      cleanup() {
        if [ -n "$INHIBITOR_PID" ]; then kill "$INHIBITOR_PID"; fi
        exit
      }
      trap cleanup EXIT TERM INT

      while true; do
        if grep -q 1 /sys/class/power_supply/AC*/online 2>/dev/null; then
          if [ -z "$INHIBITOR_PID" ]; then
            echo "AC connected: Inhibiting idle suspend"
            ${pkgs.systemd}/bin/systemd-inhibit --what=idle --who="ac-idle-suppress" --why="AC connected" --mode=block sleep infinity &
            INHIBITOR_PID=$!
          fi
        else
          if [ -n "$INHIBITOR_PID" ]; then
            echo "AC disconnected: Allowing idle suspend"
            kill "$INHIBITOR_PID"
            wait "$INHIBITOR_PID" 2>/dev/null
            INHIBITOR_PID=""
          fi
        fi
        sleep 10
      done
    '';
    serviceConfig = {
      Restart = "always";
    };
  };
}
