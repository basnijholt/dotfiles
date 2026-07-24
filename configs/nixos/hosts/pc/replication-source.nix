# ZFS replication source: the NAS pulls this machine's snapshots.
#
# Deliberately pull-based, unlike optional/zfs-replication.nix (which pushes
# as root@nas): this machine runs agentic AI all day, so it must hold no
# credentials that can reach the NAS. The NAS connects here instead, as a
# dedicated non-root user whose only power is the ZFS delegation below. Even
# a full compromise of this machine cannot reach the NAS-side snapshots that
# protect its own backups. The pull job lives in hosts/nas/replication.nix.
{ pkgs, ... }:

{
  imports = [
    ../../optional/zfs-sanoid.nix
  ];

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
      ''from="192.168.1.4" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFf8RpaZe1lGYuLI9ASLGLd6zNlkhIlRXK8hpuXiq+Os nas-replication-pc''
    ];
  };

  # ZFS delegation is pool state, not config, so reapply it every boot.
  # snapshot/hold/release/destroy cover syncoid's sync snapshots on the
  # source side; destroy requires mount on Linux. None of this grants any
  # write access to the datasets' contents.
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
}
