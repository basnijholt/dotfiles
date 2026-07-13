{
  services.nfs.server = {
    enable = true;
    nproc = 20;
    exports = ''
      "/mnt/ssd/docker/data" 192.168.1.2(rw,sync,no_subtree_check,no_root_squash,crossmnt) 192.168.1.3(rw,sync,no_subtree_check,no_root_squash,crossmnt) 192.168.1.5(rw,sync,no_subtree_check,no_root_squash,crossmnt)
      "/mnt/ssd/docker/stacks" 192.168.1.2(rw,sync,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,no_subtree_check,no_root_squash)
      "/mnt/tank/youtube" 192.168.1.2(rw,sync,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,no_subtree_check,no_root_squash)
      "/mnt/tank/frigate" 192.168.1.2(rw,sync,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,no_subtree_check,no_root_squash)
      "/mnt/tank/media" 192.168.1.2(rw,sync,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,no_subtree_check,no_root_squash)
      "/mnt/tank/syncthing" 192.168.1.2(rw,sync,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,no_subtree_check,no_root_squash)
      "/mnt/tank/photos-export" 192.168.1.2(rw,sync,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,no_subtree_check,no_root_squash)
    '';
  };
}
