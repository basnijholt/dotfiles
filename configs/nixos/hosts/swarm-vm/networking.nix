# Network configuration for Swarm VM
{ ... }:

{
  networking.hostName = "swarm-vm";
  networking.hostId = "a1b2c3d4"; # Required for ZFS

  # Use simple DHCP networking (Incus handles bridging)
  networking.useDHCP = true;

  networking.nftables.enable = true;
  networking.firewall.enable = true;
}
