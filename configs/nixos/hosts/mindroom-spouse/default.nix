{ lib, pkgs, ... }:

{
  imports = [
    ./networking.nix
    ../../optional/openclaw/services.nix
  ];

  # Passwordless sudo for OpenClaw agent
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # signal-cli for OpenClaw Signal channel
  environment.systemPackages = [ pkgs.signal-cli ];

  # OpenClaw is managed as a NixOS system service.
}
