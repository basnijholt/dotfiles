# Harmonia binary cache server
{ lib, ... }:

let
  keyPath = "/var/lib/harmonia/cache-priv-key.pem";
in
{
  services.harmonia = {
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

  # --- LXC Container Workaround ---
  # The lxc-container.nix drop-in clears LoadCredential=, breaking harmonia.
  # Pass the key path directly via environment variable instead.
  # See: https://github.com/NixOS/nixpkgs/issues/260670
  systemd.services.harmonia.environment.SIGN_KEY_PATHS = lib.mkForce keyPath;

  # Ensure harmonia key directory and file have correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/harmonia 0755 root root -"
  ];
}
