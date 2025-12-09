# Nix build optimization settings for large builds (CUDA, PyTorch)
{ ... }:

{
  # --- Build Parallelism ---
  nix.settings = {
    max-jobs = 1; # Single build at a time to prevent OOM on PyTorch/CUDA
    cores = 1; # Single core per job to minimize peak memory usage

    # Disable sandbox (required for Incus containers)
    sandbox = false;

    # Allow trusted users to copy unsigned paths to the store
    # Harmonia will sign them on-the-fly when serving
    require-sigs = false;

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

  # --- Swap for Peak Memory ---
  # Safety net for memory-intensive builds like PyTorch/CUDA
  swapDevices = [{
    device = "/var/swapfile";
    size = 64 * 1024; # 64GB swap
  }];
}
