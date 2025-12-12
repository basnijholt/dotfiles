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

  # concise power management: udev triggers inhibitor service when AC connects
  systemd.services.ac-idle-block = {
    description = "Inhibit idle suspend when on AC";
    serviceConfig.ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=ac-udev --mode=block sleep infinity";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start ac-idle-block.service"
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl stop ac-idle-block.service"
  '';
}
