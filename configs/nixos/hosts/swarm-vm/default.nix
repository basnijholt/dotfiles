# Docker Swarm manager VM for TrueNAS Incus
#
# This is a dedicated Swarm manager node running as an Incus VM.
# Part of the 3-node HA control plane: hp, nuc, swarm-vm
{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/virtualization.nix
    ../../optional/docker-swarm.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  # Swarm configuration - joins hp as the bootstrap manager
  my.swarm = {
    enable = true;
    role = "manager";
    advertiseAddr = "eth0"; # Use interface name, DHCP assigns IP
    managerAddr = "hp.lan"; # Bootstrap manager to join
    managerTokenFile = "/root/secrets/swarm-manager.token";
  };
}
