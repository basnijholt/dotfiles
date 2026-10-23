{ pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/desktop.nix
    ../../optional/audio.nix
    ../../optional/virtualization.nix
    ../../optional/gui-packages.nix
    ../../optional/large-packages.nix
    ../../optional/power.nix
    ../../optional/ups-client.nix
    ../../optional/wake-on-lan.nix
    ../../optional/nfs-docker.nix
    ../../optional/zfs-replication-source.nix

    # Host-specific modules (Tier 3)
    ./boot.nix
    ./storage.nix
    ./networking.nix
    ./package-overrides.nix
    ./1password.nix
    ./system-packages.nix
    ./keyboard-remap.nix
    ./gaming.nix
    ./debugging.nix
    ./ai.nix
    ./nvidia-graphics.nix
    ./nvidia-undervolt.nix
    ./slurm.nix
  ];

  local.wakeOnLan.interface = "enp5s0";
  local.zfsReplicationSource.nasPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFf8RpaZe1lGYuLI9ASLGLd6zNlkhIlRXK8hpuXiq+Os nas-replication-pc";
  local.t3code = {
    enable = true;
    host = "0.0.0.0";
  };
  local.paseo = {
    enable = true;
    host = "0.0.0.0";
  };

  # Required for DDC/CI tools such as ddcutil to read monitor state (e.g. the
  # active input source) for manual diagnostics. Display automation no longer
  # depends on it; Sunshine drives dummy-output switching via sunshine-mode.sh.
  # Also used by rgb-leds-off below.
  hardware.i2c.enable = true;

  # Turn off the RGB LEDs on both ASUS ROG Strix 3090s and the Crosshair VIII
  # Hero (onboard LEDs and its RGB headers). Select by name because indices
  # shift when a device is not detected; openrgb exits non-zero when a name
  # matches nothing.
  systemd.services.rgb-leds-off = {
    description = "Turn off RGB LEDs";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.openrgb}/bin/openrgb --noautoconnect --device \"RTX 3090\" --mode off --device CROSSHAIR --mode off";
    };
  };

  environment.systemPackages = with pkgs; [
    ddcutil
  ];
}
