{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: HP is a headless server, so no desktop/audio/gui-packages
    ../../optional/virtualization.nix
    ../../optional/large-packages.nix
    ../../optional/power.nix
    ../../optional/iscsi.nix
    ../../optional/zfs-replication.nix
    ../../optional/nfs-docker.nix
    ../../optional/print-server.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./ups.nix
  ];

  # Allow user to manage printers via web UI
  users.users.basnijholt.extraGroups = [ "lpadmin" ];

  # Required for ZFS
  networking.hostId = "37a1d4a7";
}
