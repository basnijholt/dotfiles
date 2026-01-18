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
    ../../optional/coredns.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./system-packages.nix
    ./kodi.nix
  ];

  # Required for ZFS
  networking.hostId = "8a5b2c1f";

  local.wakeOnLan.interface = "eno1";

  # Primary DNS server
  local.coredns = {
    enable = true;
    listenIP = "192.168.1.2";
    extraSystemdDeps = [ "sys-subsystem-net-devices-br0.device" ];
  };

  # Route to WireGuard subnet via ASUS router for DNS responses to reach VPN clients
  systemd.network.networks."40-br0".routes = [
    {
      Destination = "10.6.0.0/24";
      Gateway = "192.168.1.1";
    }
  ];
}
