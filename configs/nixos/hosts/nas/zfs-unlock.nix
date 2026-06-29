{
  services.zfsUnlock.receiver = {
    enable = true;
    allowedFrom = [ "192.168.1.7" ];
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHwr8WDLxJiDap7nSB3WgFw/pI7x6AdInjajpu+r+Z4l pi4-zfs-unlock"
    ];
    datasets = [
      "tank/syncthing"
      "tank/frigate"
      "tank/photos"
      "tank/stash"
      "tank/photos-export"
    ];
  };
}
