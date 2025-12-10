{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: HP is a headless server, so no desktop/audio/gui-packages
    ../../optional/virtualization.nix
    ../../optional/docker-swarm.nix
    ../../optional/power.nix
    ../../optional/iscsi.nix
    ../../optional/zfs-replication.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  # Required for ZFS
  networking.hostId = "37a1d4a7";

  # Swarm configuration - HP is the bootstrap manager
  my.swarm = {
    enable = true;
    role = "manager";
    advertiseAddr = "br0"; # Use bridge interface
    # No managerAddr = this is the bootstrap node
  };
}
