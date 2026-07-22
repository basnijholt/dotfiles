# Backup configuration (Restic to the NAS)
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
      "/var/lib/qdrant"  # Vector database
      "/var/lib/incus"   # Virtual machines and containers
      "/var/lib/munge"   # Munge authentication
      "/var/lib/private/ollama" # AI models
      "/var/lib/libvirt" # Libvirt VMs
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
      OnCalendar = "hourly";
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
