# Tang key server for the NAS's encrypted root pool. At boot, Clevis in
# the NAS's initrd asks this server to recover the pool's passphrase, so
# the NAS unlocks unattended only while the pi4 is reachable. Tang stores
# nothing about the NAS; its only state is the key pair it generates in
# /var/lib/tang. If that is lost, the NAS asks for the passphrase instead.
{
  services.tang = {
    enable = true;
    # The NAS's static address, which its initrd uses too.
    ipAddressAllow = [ "192.168.1.4/32" ];
  };
  networking.firewall.allowedTCPPorts = [ 7654 ];
}
