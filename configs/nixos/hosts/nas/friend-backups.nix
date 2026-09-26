# Friend-to-friend off-site backups with Joe via zfs-tenant
# (https://github.com/basnijholt/zfs-tenant). Each of us hosts a
# quota-capped tenant root for the other and pushes raw encrypted sanoid
# snapshots into our own root on the other's pool with plain syncoid, so
# neither side ever holds the other's encryption keys.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Each direction stays off until Joe has sent the details it needs.
  joe = {
    # Hosting Joe: the public key of his syncoid user, and the address his
    # pushes arrive from. His NAS reaches the tailnet through his router's
    # subnet route, which source-NATs to the router's tailnet IP.
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVKYYZ2SZF9PhBKy5n3Nxse6GGI3dQGtQZBeHP4iHtJ"
    ];
    allowedFrom = [ "100.64.0.20" ];

    # Pushing to Joe: the address and SSH host key of his NAS as the NAS
    # reaches it, and the tenant user and root he created for us.
    address = null;
    hostKey = null;
    user = "zfs-tenant-bas";
    root = null;
  };

  hostingJoe = joe.authorizedKeys != [ ] && joe.allowedFrom != [ ];
  pushingToJoe = joe.address != null && joe.hostKey != null && joe.root != null;

  # Raw sends keep our blocks encrypted with our own keys on Joe's pool, so
  # every dataset listed here must be encrypted. Joe can still see dataset
  # and snapshot names and sizes.
  pushedDatasets = [ "tank/offsite-test" ];

  syncoidKey = "/var/lib/syncoid/id_ed25519";
in
{
  services.zfs-tenant = {
    enable = hostingJoe;
    tenants.joe = {
      dataset = "tank/friends/joe";
      quota = "2T";
      inherit (joe) authorizedKeys allowedFrom;
    };
  };

  # Joe's datasets mirror his own sanoid retention: our sanoid must neither
  # snapshot nor prune them, or his next incremental push would find
  # snapshots on the target that he never sent.
  services.sanoid.datasets."tank/friends" = lib.mkIf hostingJoe {
    autosnap = false;
    autoprune = false;
    recursive = true;
  };

  programs.ssh.knownHosts.joe-nas = lib.mkIf pushingToJoe {
    hostNames = [ joe.address ];
    publicKey = joe.hostKey;
  };

  # --no-sync-snap sends only sanoid's snapshots, so the syncoid user needs
  # just send and hold on the source; the gate on Joe's side refuses sudo,
  # and mbuffer/lzop do nothing for raw encrypted streams. syncoid stays
  # enabled without commands so its user and key exist before Joe has
  # our public key.
  services.syncoid = {
    enable = true;
    sshKey = syncoidKey;
    localSourceAllow = [
      "send"
      "hold"
    ];
    commonArgs = [
      "--no-sync-snap"
      "--compress=none"
      "--delete-target-snapshots"
      "--sshoption=StrictHostKeyChecking=yes"
    ];
    commands = lib.mkIf pushingToJoe (
      lib.genAttrs pushedDatasets (dataset: {
        target = "${joe.user}@${joe.address}:${joe.root}/${baseNameOf dataset}";
        recursive = true;
        sendOptions = "w";
      })
    );
  };

  # The private key never leaves the NAS; Joe only gets the .pub half.
  systemd.services.syncoid-ssh-key = {
    description = "Generate the SSH key syncoid pushes to Joe with";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "!${syncoidKey}";
    serviceConfig = {
      Type = "oneshot";
      User = config.services.syncoid.user;
      Group = config.services.syncoid.group;
      StateDirectory = "syncoid";
      StateDirectoryMode = "700";
      ExecStart = "${lib.getExe' pkgs.openssh "ssh-keygen"} -t ed25519 -N '' -C syncoid@nas -f ${syncoidKey}";
    };
  };
}
