# Harmonia binary cache server
{ ... }:

{
  services.harmonia = {
    enable = true;
    signKeyPaths = [ "/var/lib/harmonia/cache-priv-key.pem" ];
    settings = {
      bind = "[::]:5000";
      workers = 4;
      max_connection_rate = 256;
      priority = 50; # Lower than cache.nixos.org (40)
    };
  };

  # Ensure harmonia key directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/harmonia 0750 harmonia harmonia -"
  ];
}
