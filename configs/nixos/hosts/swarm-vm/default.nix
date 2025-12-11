# Docker Swarm manager VM for TrueNAS Incus
# Part of 3-node HA control plane: hp (bootstrap), nuc, swarm-vm
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/virtualization.nix
    ../../optional/docker-swarm.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  my.swarm.join = "eth0";
}
