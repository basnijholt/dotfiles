{
  services.nfs.server = {
    enable = true;
    nproc = 20;
    # mp: export a path only while its dataset is mounted. An encrypted
    # dataset stays unmounted until its key arrives after boot, and without
    # mp the clients would mount and write into the empty directory below.
    exports = ''
      "/mnt/ssd/docker/data" 192.168.1.2(rw,sync,mp,no_subtree_check,no_root_squash,crossmnt) 192.168.1.3(rw,sync,mp,no_subtree_check,no_root_squash,crossmnt) 192.168.1.5(rw,sync,mp,no_subtree_check,no_root_squash,crossmnt)
      "/mnt/ssd/docker/stacks" 192.168.1.2(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,mp,no_subtree_check,no_root_squash)
      "/mnt/tank/youtube" 192.168.1.2(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,mp,no_subtree_check,no_root_squash)
      "/mnt/tank/frigate" 192.168.1.2(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,mp,no_subtree_check,no_root_squash)
      "/mnt/tank/media" 192.168.1.2(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,mp,no_subtree_check,no_root_squash)
      "/mnt/tank/syncthing" 192.168.1.2(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,mp,no_subtree_check,no_root_squash)
      "/mnt/tank/photos-export" 192.168.1.2(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.3(rw,sync,mp,no_subtree_check,no_root_squash) 192.168.1.5(rw,sync,mp,no_subtree_check,no_root_squash)
    '';
  };
}
