# Gaming configuration (Bluetooth, Xbox controllers, Steam)
{ pkgs, ... }:

{
  # --- Bluetooth ---
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

  # --- Xbox Controller Support ---
  # Advanced driver for modern Xbox wireless controllers
  hardware.xpadneo.enable = true;
  # Disable ERTM to fix Bluetooth controller lag/disconnects
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=Y
  '';

  # --- Steam ---
  programs.steam.enable = true;

  # --- Sunshine (Game Streaming) ---
  # Note: Had to change per https://discourse.nixos.org/t/give-user-cap-sys-admin-p-capabillity/62611/2
  # In Sunshine Steam App use `sudo -u myuser setsid steam steam://open/bigpicture` as Detached Command.
  # In Steam Settings: Interface -> enable "GPU accelerated..." but disable "hardware video decoding".
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
}
