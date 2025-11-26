# Network configuration for HP server
{ ... }:

{
  networking.hostName = "hp";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.networkmanager.enable = false;

  # --- Systemd-Networkd (Bridge for VMs) ---
  networking.useDHCP = false; # Disable legacy scripted networking
  systemd.network.enable = true;

  # 1. Create the bridge device
  systemd.network.netdevs."20-br0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
      MACAddress = "c8:d9:d2:0c:e0:34"; # Mimic eno1 MAC for Static DHCP
    };
  };

  # 2. Bind physical interface to bridge
  systemd.network.networks."30-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig.Bridge = "br0";
    linkConfig.RequiredForOnline = "no"; # Avoid boot hangs if cable issue
  };

  # 3. Configure the bridge (DHCP)
  systemd.network.networks."40-br0" = {
    matchConfig.Name = "br0";
    networkConfig.DHCP = "yes";
  };

  # --- Firewall ---
  networking.firewall.trustedInterfaces = [ "br0" "incusbr0" ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; }  # mosh
  ];
}
