# Stream Deck + XL daemon (https://github.com/basnijholt/streamdeck).
# `deck` is installed outside Nix with `uv tool install git+https://github.com/basnijholt/streamdeck`;
# ~/.config/deck/config.yaml and secrets.env are linked by the dotfiles and secrets installers.
{ pkgs, ... }:

{
  # The deck for the `users` group, also without a desktop session (uaccess needs one).
  services.udev.extraRules = ''
    KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", MODE="0660", GROUP="users"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", MODE="0660", GROUP="users"
  '';

  # Monitor brightness and input over DDC/CI (hardware.i2c.enable is in default.nix).
  users.users.basnijholt.extraGroups = [ "i2c" ];

  systemd.user.services.deck = {
    description = "Stream Deck + XL daemon";
    wantedBy = [ "default.target" ];
    # fc-match finds the emoji and text fonts; without it every icon is a box.
    path = [ pkgs.ddcutil pkgs.fontconfig ];
    environment = {
      LD_LIBRARY_PATH = "${pkgs.hidapi}/lib";
      # uv's Python looks for /etc/ssl/cert.pem, which NixOS does not have.
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
    serviceConfig = {
      ExecStart = "%h/.local/bin/deck run %h/.config/deck/config.yaml";
      EnvironmentFile = "%h/.config/deck/secrets.env";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
