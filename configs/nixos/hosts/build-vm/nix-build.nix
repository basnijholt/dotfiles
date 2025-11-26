# Nix build optimization settings for large builds (CUDA, PyTorch)
{ ... }:

{
  # --- Build Parallelism ---
  nix.settings = {
    max-jobs = "auto";
    cores = 0; # Use all available cores per job

    # Disable sandbox (required for Incus containers)
    sandbox = false;

    # Enable big-parallel for memory-intensive builds
    system-features = [ "big-parallel" "kvm" "nixos-test" ];

    # Keep build dependencies for faster rebuilds
    keep-outputs = true;
    keep-derivations = true;
  };

  # --- Nix Daemon Limits ---
  # Increase limits for large builds
  systemd.services.nix-daemon.serviceConfig = {
    LimitNOFILE = 1048576;
    LimitNPROC = 1048576;
  };

  # --- Tmpdir Configuration ---
  # Use disk-backed /tmp instead of tmpfs to avoid OOM on large builds
  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };

  # Alternative build directory with more space if needed
  systemd.tmpfiles.rules = [
    "d /var/cache/nix-build 0755 root root -"
  ];
}
