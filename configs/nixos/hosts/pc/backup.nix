# Backup configuration (Restic to the NAS)
#
# TODO: restic is being phased out in favor of ZFS replication (sanoid here,
# syncoid pull from the NAS, see hosts/nas/replication.nix). Once a few clean
# pull runs
# have landed on the NAS and one restore drill from the replicas has passed:
# demote this timer to daily, and retire or relax the "pc restic repo"
# freshness check in hosts/nas/replication.nix in the same change. Keep the
# repository on the NAS either way — it is the only file-level history and
# the only restore path exercised end-to-end.
#
# The NAS address is deliberately its static LAN IP, not a hostname: name
# resolution failures break this job silently. The restic user and its
# authorized_keys live on the NAS tank pool.
{ ... }:

{
  services.restic.backups.truenas = {
    repository = "sftp:restic@192.168.1.4:/mnt/tank/backups/pc";
    paths = [
      "/home"
      "/etc/nixos"
      "/root/.ssh"       # Important: backup SSH keys!
      "/var/lib/incus"   # Virtual machines and containers
      "/var/lib/munge"   # Munge authentication
      "/var/lib/private/ollama" # AI models
      "/var/lib/libvirt" # Libvirt VMs
      "/var/lib/systemd/credential.secret" # host key for systemd-creds — without it every host-sealed credential (e.g. libvirt secrets-encryption-key) dies with the machine
    ];
    exclude = [
      "/home/*/.cache"
      "/home/*/Downloads"
      "*.tmp"
      "node_modules"
    ];
    passwordFile = "/root/.restic-password";
    extraOptions = [
      "sftp.command='ssh -i /root/.ssh/restic-backup -o StrictHostKeyChecking=no restic@192.168.1.4 -s sftp'"
    ];
    timerConfig = {
      # Every 6 hours: a full scan walks ~98M files and takes ~1h25, so the
      # old hourly timer just meant back-to-back scanning for ~200 MiB of
      # changes per run.
      OnCalendar = "*-*-* 00/6:00:00";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-hourly 24"
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
    ];
    initialize = true;
  };
}
