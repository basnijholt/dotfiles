# Storage configuration (ZFS maintenance, service dirs)
#
# Snapshots come from sanoid (optional/zfs-sanoid.nix via zfs-replication-source.nix,
# imported in default.nix) — the snapper configs died with btrfs. Swap is a
# 96G partition from disko.nix: swapfiles are not supported on ZFS.
{ lib, ... }:

let
  # Snapshot-free scratch datasets for agent worktrees (see below).
  scratch = dataset: mountPoint: {
    "${mountPoint}" = {
      device = "zroot/scratch/${dataset}";
      fsType = "zfs";
      # No nofail: it would let boot (and incus) go on before the mount, and
      # incus would then bind the empty directory underneath. The datasets are
      # on zroot, which / needs anyway.
    };
  };
in
{
  # --- ZFS Maintenance ---
  # Pool-level autotrim is on (common/disko-zfs.nix); these add the periodic
  # scrub for bitrot detection and a weekly full trim pass.
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Cap the ZFS ARC at 16 GiB. The OpenZFS default on this kernel lets ARC grow
  # to all 64 GiB of RAM; under many parallel agent builds it held ~16 GiB while
  # ~36 GiB of application memory was pushed to swap.
  boot.extraModprobeConfig = ''
    options zfs zfs_arc_max=17179869184
  '';

  # --- Snapshots ---
  # The NAS pull (nas-replicate-pc) keeps the long history and prunes it with
  # nas-backup-prune, so pc only keeps a short window, like hetzner-matrix.
  # Sanoid still takes every weekly and monthly snapshot, so the NAS still
  # receives them. Each snapshot here pins all data deleted since it was
  # taken, and agent churn made 12 monthlies pin over a terabyte.
  services.sanoid.templates.zfs-default = {
    daily = lib.mkForce 3;
    weekly = lib.mkForce 1;
    monthly = lib.mkForce 1;
  };

  # Agent worktrees (T3 Code's, the mindroom container's, ~/repos/worktrees)
  # are rebuilt from git, yet their node_modules and build output were most
  # of the snapshot churn: ~240 GB/day on zroot/var (the mindroom container's
  # worktrees) and ~270 GB/week on zroot/home (T3's). They live on
  # zroot/scratch, which sanoid skips and nas-replicate-pc never pulls (it
  # pulls only home, var, root and incus). The datasets are created by hand
  # (zfs create -o mountpoint=legacy zroot/scratch/<name>), and their content
  # must be moved in before this config mounts them over the old directories.
  # Snapshots sanoid took of zroot/scratch before this config deployed are
  # not pruned (autoprune = false): destroy them by hand.
  services.sanoid.datasets."zroot/scratch" = {
    autosnap = false;
    autoprune = false;
    recursive = true;
  };
  fileSystems =
    scratch "t3-worktrees" "/home/basnijholt/.t3/worktrees"
    // scratch "repos-worktrees" "/home/basnijholt/repos/worktrees"
    # Passed into the mindroom container as its ~/repos/worktrees with
    # `incus config device add mindroom worktrees disk source=... path=...
    # shift=true` (the container's rootfs is idmapped too, so files keep the
    # container's own uids on disk).
    // scratch "mindroom-worktrees" "/var/lib/mindroom-worktrees";

  # --- Swap ---
  # Compressed swap in RAM, used before the 96G partition (zram's priority 5
  # beats the partition's -2). The partition shares the NVMe with zroot, and
  # swapping wrote ~285 GB/day there, competing with every ZFS write.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # Never restart zram on switch; see hosts/hetzner/default.nix.
  systemd.units."systemd-zram-setup@zram0.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      X-RestartIfChanged=false
      X-StopIfChanged=false
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/club-3090-vllm 0755 root root -"
    "d /var/lib/club-3090-vllm/models 0755 root root -"
    "d /var/lib/club-3090-vllm/cache 0755 root root -"
    "d /var/lib/club-3090-vllm/cache/torch_compile 0755 root root -"
    "d /var/lib/club-3090-vllm/cache/triton 0755 root root -"
  ];
}
