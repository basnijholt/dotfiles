# Network configuration for HP server
{ pkgs, ... }:

{
  networking.hostName = "hp";
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.networkmanager.enable = false;

  # --- Systemd-Networkd (Bridge for VMs) ---
  networking.useDHCP = false; # Disable legacy scripted networking
  systemd.network.enable = true;

  # --- e1000e Hardware Hang Workaround ---
  # Intel I219-LM NIC can hang with offloading enabled, causing
  # "Detected Hardware Unit Hang" errors and network resets.
  # Fix: disable hardware offloading via ethtool at boot.
  # References:
  #   - https://forum.proxmox.com/threads/e1000e-eno1-detected-hardware-unit-hang.59928/page-2
  #   - https://forum.proxmox.com/threads/intel-nic-e1000e-hardware-unit-hang.106001/
  #   - https://gist.github.com/brunneis/0c27411a8028610117fefbe5fb669d10
  systemd.services.e1000e-workaround = {
    description = "Disable hardware offloading on e1000e to prevent hangs";
    after = [ "network-pre.target" ];
    before = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.ethtool}/bin/ethtool -K eno1 tso off gso off";
    };
  };

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
}
