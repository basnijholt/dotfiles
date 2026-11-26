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
      # nofail keeps a missing dataset (e.g. after a NAS restore, which has no
      # scratch) from stopping the boot, but drops the ordering before
      # local-fs.target, so add it back: incus and T3 Code must start after
      # the mounts, or incus binds the empty directory underneath.
      options = [
        "nofail"
        "x-systemd.before=local-fs.target"
      ];
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

  # common/services.nix sets freeSwapThreshold = 10, which with 111 GiB of
  # total swap (15.7 GiB zram + 96 GiB NVMe) waits until >100 GiB of swap is
  # filled — pc froze at 40+ GiB swap and tripped the AMD hardware watchdog.
  # 70% free fires once >~33 GiB swap is used (zram full + ~18 GiB NVMe) while
  # <10% RAM is available.
  services.earlyoom = {
    freeSwapThreshold = lib.mkForce 70;
    extraArgs = [
      "--prefer"
      "^(node|tsc|eslint|vitest|pytest|chromium|chrome|cargo|rustc|cc1plus)$"
      "--avoid"
      "^(systemd|sshd|mindroom|\\.?Hyprland(-wrapp)?|sway|tuwunel)$"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/club-3090-vllm 0755 root root -"
    "d /var/lib/club-3090-vllm/models 0755 root root -"
    "d /var/lib/club-3090-vllm/cache 0755 root root -"
    "d /var/lib/club-3090-vllm/cache/torch_compile 0755 root root -"
    "d /var/lib/club-3090-vllm/cache/triton 0755 root root -"
  ];
}
