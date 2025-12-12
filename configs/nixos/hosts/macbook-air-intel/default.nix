{ pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: Intel MacBook Air
    ../../optional/virtualization.nix
    ../../optional/apple-t2.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "ignore";
    settings.Login = {
      IdleAction = "suspend";
      IdleActionSec = "30m";
    };
  };

  # --- Power Management for Headless Server ---
  # Goal: Sleep aggressively on battery, NEVER sleep on AC.
  # 1. logind (above) handles battery behavior (suspend on lid/idle).
  # 2. This udev rule + service inhibits sleep whenever AC is connected.
  systemd.services.ac-idle-block = {
    description = "Inhibit idle suspend when on AC";
    serviceConfig.ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=ac-udev --mode=block sleep infinity";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start ac-idle-block.service"
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl stop ac-idle-block.service"
  '';

  # Temporary fix: Make /lib/firmware writable to allow manual extraction on each boot
  # TODO: Replace with permanent hardware.firmware inclusion once files are extracted to repo.
  systemd.services.make-firmware-writable = {
    description = "Make /lib/firmware writable for WiFi driver extraction";
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ util-linux coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /tmp/fw-upper /tmp/fw-work
      mount -t overlay overlay -o lowerdir=/lib/firmware,upperdir=/tmp/fw-upper,workdir=/tmp/fw-work /lib/firmware
      mkdir -p /lib/firmware/brcm
    '';
  };

  # --- T2 Hardware Support ---
  # The 'nixos-hardware.nixosModules.apple-t2' module (imported in flake.nix)
  # handles kernel patches for the T2 chip (SSD, Keyboard, etc.).
  #
  # This utility script extracts the REQUIRED proprietary firmware (WiFi/BT)
  # from the internal macOS partition, as we cannot legally redistribute it.
}
