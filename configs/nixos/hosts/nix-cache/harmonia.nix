# Harmonia binary cache server
{ lib, ... }:

let
  keyPath = "/var/lib/harmonia/cache-priv-key.pem";
in
{
  users.groups.harmonia = { };
  users.users.harmonia = {
    isSystemUser = true;
    group = "harmonia";
    home = "/var/lib/harmonia";
  };

  services.harmonia.cache = {
    enable = true;
    # Don't use signKeyPaths - it uses LoadCredential which is broken in LXC
    signKeyPaths = lib.mkForce [ ];
    settings = {
      bind = "[::]:5000";
      workers = 4;
      max_connection_rate = 256;
      priority = 50; # Lower than cache.nixos.org (40)
    };
  };

  systemd.services.harmonia.serviceConfig.DynamicUser = lib.mkForce false;

  # --- LXC Container Workaround ---
  # The lxc-container.nix drop-in clears LoadCredential=, breaking harmonia.
  # Pass the key path directly via environment variable instead.
  # See: https://github.com/NixOS/nixpkgs/issues/260670
  systemd.services.harmonia.environment.SIGN_KEY_PATHS = lib.mkForce keyPath;

  # Ensure harmonia can read the persistent signing key across service restarts.
  systemd.tmpfiles.rules = [
    "d /var/lib/harmonia 0750 harmonia harmonia -"
    "z ${keyPath} 0600 harmonia harmonia -"
  ];
}
