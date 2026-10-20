{ ... }:

{
  imports = [
    ../../optional/mindroom-companion.nix
    ./networking.nix
  ];

  # Passwordless sudo for basnijholt
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];
}
