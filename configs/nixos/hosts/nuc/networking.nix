# Network configuration for NUC media box
{ lib, ... }:

{
  # --- TrueNAS ZFS Replication (incoming) ---
  # Allow root login with key-only for ZFS receive from TrueNAS
  # Key: "nuc Key" from http://truenas.local/ui/credentials/backup-credentials
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjQXxVKo4Oo4mGuxYxcjFwMoCjL7ykJhDGiC5T7C9vDdEEG2sCQo1vRgLYlLzUwv0Ibgfl1VMcr+eiTof1pth+/BQ20wTjfbcVZQFCg50Qq0VE7gOtFulJy9nMoefbZg+h/1j0A8yvz6pb88koYmpKjC3+HMk1M74EzG1RNK5dEY7LcuX5D1fsDwUOXQKF3Pw7I538Fkq8y49xg0F779gqkEX4AyFmzrjSfid535G4yYL1kcQqqX0znpfWoMHhq00AiaVyzr/b9CEKtwEUlW3PAIlzR/410NzJ67NjFh7Uks11mPprDmd7Cq8/hb8d6DeGTNTuIHkog8nwMU8GifGi8oOXzVZS09QVVYEXfc5HMY86cvpt8fgE76rJO6wKm3IBp+KCTCWV4kFA/dPJyXxjsBD8BpV8shiiCV5DbYmZDjIyFQNXE3XboHc2C5qmJoHLbxAYdXdwf/ZLa8FDnJRvy+z0mMDF5iQQ1ryexJdedDA+JFA+pmk5rGEgykfF6iE= root@truenas"
  ];

  networking.hostName = "nuc";

  # Static host entry for NFS mounts - avoids race condition where mounts
  # try to resolve before CoreDNS is ready at boot
  networking.extraHosts = ''
    192.168.1.4 truenas.local
  '';

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
      MACAddress = "1c:69:7a:0c:b6:37"; # Mimic eno1 MAC for Static DHCP
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
  networking.firewall.allowedTCPPorts = [
    8080  # Kodi web interface
    8443  # Incus
  ];
}
