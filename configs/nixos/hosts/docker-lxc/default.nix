{ lib, ... }:

{
  imports = [
    ../dev-lxc/default.nix
    ../../optional/lxc-container.nix
    ../../optional/kcptun.nix
    ./packages.nix
    ./rclone-b2-backup.nix
    ./github-backup-sync.nix
  ];

  networking.hostName = lib.mkForce "docker-lxc";
  networking.firewall.allowedTCPPorts = [ 9001 ];
  hardware.graphics.enable = true;
  services.syncthing.enable = lib.mkForce false;
  virtualisation.docker.daemon.settings.dns = lib.mkForce ["192.168.1.2" "192.168.1.3" "1.1.1.1"];

  # kcptun server for transatlantic streaming with FEC
  # Provides UDP tunnel with Forward Error Correction to handle packet loss
  # Client on Hetzner connects here, gets ~80 Mbps vs ~35 Mbps without FEC
  services.kcptun.server = {
    enable = true;
    listenPort = 29900;           # UDP port for kcptun
    targetHost = "127.0.0.1";
    targetPort = 5201;            # Forward to iperf3 for testing (change to 22 for SSH)
    key = "transatlantic-fec-tunnel-2026";
    datashard = 10;               # 10 data shards
    parityshard = 3;              # 3 parity shards = ~23% overhead, can recover 3/13 = 23% loss
  };
}
