# Virtualisation stack (Docker, libvirt, Incus)
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.distrobox ];
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.incus.enable = true;
  programs.virt-manager.enable = true;
}
