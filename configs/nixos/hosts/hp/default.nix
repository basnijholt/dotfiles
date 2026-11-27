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

  # Small pool: long-lived snapshots pin churn the disk can't afford. Keep
  # short-term rollback, cut the long tail; the NAS mirror holds deep history.
  # Dataset-level values override the zfs-default template.
  services.sanoid.datasets.zroot = {
    daily = 5;
    weekly = 2;
    monthly = 1;
  };
}
