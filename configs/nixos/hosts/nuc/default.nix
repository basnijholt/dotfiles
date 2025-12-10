{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/desktop.nix
    ../../optional/audio.nix
    ../../optional/virtualization.nix
    ../../optional/docker-swarm.nix
    ../../optional/gui-packages.nix
    ../../optional/power.nix
    ../../optional/iscsi.nix
    ../../optional/zfs-replication.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./system-packages.nix
    ./kodi.nix
  ];

  # Required for ZFS
  networking.hostId = "8a5b2c1f";

  # Swarm configuration - NUC joins HP as a manager
  my.swarm = {
    enable = true;
    role = "manager";
    advertiseAddr = "br0"; # Use bridge interface
    managerAddr = "hp.lan"; # Join HP's swarm
    managerTokenFile = "/root/secrets/swarm-manager.token";
  };
}
