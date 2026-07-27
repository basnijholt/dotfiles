# Virtualisation stack (Docker, libvirt, Incus)
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.distrobox ];
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.incus.enable = true;
  programs.virt-manager.enable = true;

  # Incus manages its own snapshots; keep sanoid away from its datasets.
  # Fleet convention: the incus storage pool lives on zroot/incus. Inert on
  # hosts without sanoid; on hosts where the dataset does not exist (yet),
  # sanoid logs one harmless zfs-list complaint per run and carries on.
  services.sanoid.datasets."zroot/incus" = {
    autosnap = false;
    autoprune = false;
    recursive = true;
  };
}
