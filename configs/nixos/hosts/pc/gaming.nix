{ pkgs, ... }:

{
  # --- Bluetooth & Xbox Controller ---
  services.blueman.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # Automatically powers on Bluetooth after booting.
    settings.General = {
      experimental = true; # Show battery levels
      # Helps controllers reconnect more reliably.
      JustWorksRepairing = "always";
      FastConnectable = true;
    };
  };

  # Enable the advanced driver for modern Xbox wireless controllers.
  # This is crucial for proper functionality in Steam and other games.
  hardware.xpadneo.enable = true;

  # This kernel option is a common fix for Bluetooth controller issues on Linux.
  # It disables Enhanced Re-Transmission Mode, which can cause lag or disconnects.
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=Y
  '';

  programs.steam.enable = true;

  # Sunshine notes: Had to change the `https://discourse.nixos.org/t/give-user-cap-sys-admin-p-capabillity/62611/2`
  # in Sunshine Steam App `sudo -u myuser setsid steam steam://open/bigpicture` as Detached Command
  # then in Steam Settings: Interface -> "Enable GPU accelerated ..." but disable "hardware video decoding"
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
}
