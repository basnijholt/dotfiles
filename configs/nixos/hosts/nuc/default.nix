{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/desktop.nix
    ../../optional/audio.nix
    ../../optional/virtualization.nix
    ../../optional/gui-packages.nix
    ../../optional/large-packages.nix
    ../../optional/power.nix
    ../../optional/zfs-replication.nix
    ../../optional/nfs-docker.nix
    ../../optional/ups-client.nix
    ../../optional/wake-on-lan.nix
    (import ../../optional/coredns.nix { listenIP = "192.168.1.2"; })

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./system-packages.nix
    ./kodi.nix
  ];

  # Required for ZFS
  networking.hostId = "8a5b2c1f";

  local.wakeOnLan.interface = "eno1";
}
