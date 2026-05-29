{ ... }:

{
  services.ncps = {
    enable = true;
    server.addr = ":8501";

    analytics.reporting.enable = false;

    cache = {
      hostName = "nix-cache.local";
      storage.local = "/var/lib/ncps";

      maxSize = "50G";
      lru.schedule = "0 3 * * *";
      lru.scheduleTimeZone = "America/Los_Angeles";

      upstream = {
        urls = [
          "http://127.0.0.1:5000"
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://cache.nixos-cuda.org"
          "https://nixos-raspberrypi.cachix.org"
        ];

        publicKeys = [
          "build-vm-1:CQeZikX76TXVMm+EXHMIj26lmmLqfSxv8wxOkwqBb3g="
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
          "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        ];
      };

      allowPutVerb = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 8501 ];
}
