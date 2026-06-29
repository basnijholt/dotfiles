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
        # Keep Cachix-style caches out of ncps for now: some narinfos use
        # UUID-shaped NAR URLs, which ncps 0.9.4 rejects as invalid NAR hashes.
        # They are still listed as direct substituters in common/nix.nix.
        urls = [
          "http://127.0.0.1:5000"
          "https://cache.nixos.org"
        ];

        publicKeys = [
          "build-vm-1:CQeZikX76TXVMm+EXHMIj26lmmLqfSxv8wxOkwqBb3g="
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        ];
      };

      allowPutVerb = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 8501 ];
}
