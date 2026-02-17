{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: mindroom is a lightweight development container
    ../../optional/virtualization.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  # Allow basnijholt passwordless sudo (for mindroom agent)
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];
}
