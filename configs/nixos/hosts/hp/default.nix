{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: HP is a headless server, so no desktop/audio/gui-packages
    ../../optional/virtualization.nix
    ../../optional/large-packages.nix
    ../../optional/power.nix
    ../../optional/zfs-replication-source.nix
    ../../optional/nfs-docker.nix
    ../../optional/print-server.nix
    (import ../../optional/coredns.nix { listenIP = "192.168.1.3"; })

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./ups.nix
  ];

  # Allow user to manage printers via web UI
  users.users.basnijholt.extraGroups = [ "lpadmin" ];

  # Required for ZFS
  networking.hostId = "37a1d4a7";

  local.zfsReplicationSource.nasPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLaIVBmPIbB7Ot1V2bYKMnoLKj9Ga5LeMBafLzPfg7L nas-replication-hp";

  # Incus manages its own snapshots; keep sanoid away from its datasets.
  services.sanoid.datasets."zroot/incus" = {
    autosnap = false;
    autoprune = false;
    recursive = true;
  };
}
