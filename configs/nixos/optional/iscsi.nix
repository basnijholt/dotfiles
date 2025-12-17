# iSCSI initiator for connecting to TrueNAS LUNs
#
# Manual usage (if not using auto-login):
#   iscsiadm -m discovery -t sendtargets -p truenas.local
#   iscsiadm -m node -T iqn.2005-10.org.freenas.ctl:jbweston1 -p truenas.local --login
#   lsblk
{ config, pkgs, ... }:

{
  services.openiscsi = {
    enable = true;
    name = "iqn.2024-01.org.nixos:${config.networking.hostName}";
    discoverPortal = "truenas.local";
    enableAutoLoginOut = true;
  };

  environment.systemPackages = [ pkgs.openiscsi ];
}
