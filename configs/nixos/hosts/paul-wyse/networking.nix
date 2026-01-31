# Network configuration for Paul's Wyse 5070
{ lib, ... }:

{
  networking.hostName = "paul-wyse";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.networkmanager.enable = false;

  # --- Systemd-Networkd (Bridge for future VMs) ---
  networking.useDHCP = false;
  systemd.network.enable = true;

  # 1. Create the bridge device
  systemd.network.netdevs."20-br0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
      MACAddress = "e4:54:e8:4b:f0:ae"; # Match physical NIC for stable DHCP
    };
  };

  # 2. Bind physical interface to bridge
  # Wyse 5070 uses Realtek NIC, typically enp1s0 or enp2s0
  systemd.network.networks."30-lan" = {
    matchConfig.Name = "en*";
    networkConfig.Bridge = "br0";
    linkConfig.RequiredForOnline = "no";
  };

  # 3. Configure the bridge (DHCP + local CoreDNS)
  systemd.network.networks."40-br0" = {
    matchConfig.Name = "br0";
    networkConfig = {
      DHCP = "yes";
      DNS = [ "127.0.0.1" ]; # Use local CoreDNS
    };
  };

  # --- Firewall ---
  networking.firewall.trustedInterfaces = [ "br0" "incusbr0" "tailscale0" ];
  networking.firewall.allowedTCPPorts = [
    53   # DNS (CoreDNS)
    80   # HTTP (Caddy reverse proxy)
    8096 # Media server (Caddy proxy)
    8880 # Librespeed (Caddy proxy)
  ];
  networking.firewall.allowedUDPPorts = [
    53   # DNS (CoreDNS)
  ];
}
