# ZFS replication source: the NAS pulls this machine's snapshots.
#
# Deliberately pull-based, replacing the old push model (which logged in as
# root@nas): sources hold no NAS credentials at all. The NAS connects here
# instead, as a dedicated non-root user whose only power is the ZFS
# delegation below, so even a full compromise of this machine cannot reach
# the NAS or the NAS-side snapshots protecting this machine's own backups.
# The pull jobs and freshness watchdog live in hosts/nas/replication.nix;
# each host's outbound key is generated on the NAS and never leaves it.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./zfs-sanoid.nix
  ];

  options.local.zfsReplicationSource = {
    nasPublicKey = lib.mkOption {
      type = lib.types.singleLineStr;
      description = "Public half of this host's outbound replication key on the NAS.";
    };
  };

  config = {
    # syncoid on the NAS runs zfs/lz4/mbuffer on this end over SSH.
    environment.systemPackages = with pkgs; [
      lz4
      lzop
      mbuffer
    ];

    users.users.nas-replication = {
      isNormalUser = true;
      description = "NAS syncoid pull (delegated zfs send only)";
      openssh.authorizedKeys.keys = [
        ''from="192.168.1.4" ${config.local.zfsReplicationSource.nasPublicKey}''
      ];
    };

    # ZFS delegation is pool state, not config, so reapply it every boot.
    # snapshot/hold/release/destroy cover syncoid's sync snapshots on the
    # source side; destroy requires mount on Linux. Honest blast radius:
    # destroy on zroot means the key holder can delete every dataset on
    # this machine — ZFS has no snapshot-only destroy grant. That is the
    # chosen trust direction: a compromised NAS can destroy its sources,
    # but the NAS already holds every backup, so that compromise was
    # always fatal. The reverse (source compromise reaching the NAS) is
    # what this design eliminates.
    systemd.services.zfs-delegate-nas-replication = {
      description = "Delegate zfs send rights on zroot to nas-replication";
      wantedBy = [ "multi-user.target" ];
      wants = [ "zfs.target" ];
      after = [ "zfs.target" ];
      path = [ pkgs.zfs ];
      script = ''
        zfs allow -u nas-replication send,snapshot,hold,release,destroy,mount zroot
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
