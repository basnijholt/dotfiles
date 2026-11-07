# Storage configuration (ZFS maintenance, service dirs)
#
# Snapshots come from sanoid (optional/zfs-sanoid.nix via zfs-replication.nix,
# imported in default.nix) — the snapper configs died with btrfs. Swap is a
# 96G partition from disko.nix: swapfiles are not supported on ZFS.
{ ... }:

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

  systemd.tmpfiles.rules = [
    "d /var/lib/club-3090-vllm 0755 root root -"
    "d /var/lib/club-3090-vllm/models 0755 root root -"
    "d /var/lib/club-3090-vllm/cache 0755 root root -"
    "d /var/lib/club-3090-vllm/cache/torch_compile 0755 root root -"
    "d /var/lib/club-3090-vllm/cache/triton 0755 root root -"
  ];
}
