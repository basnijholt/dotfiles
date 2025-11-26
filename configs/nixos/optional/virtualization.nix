# Virtualisation stack (Docker, libvirt, Incus)
{ ... }:

{
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.incus.enable = true;
  programs.virt-manager.enable = true;
}
