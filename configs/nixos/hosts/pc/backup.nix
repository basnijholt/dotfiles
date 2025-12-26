# Backup configuration (Restic to TrueNAS)
{ ... }:

{
  services.restic.backups.truenas = {
    repository = "sftp:restic@truenas.local:/mnt/tank/backups/pc";
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
      "sftp.command='ssh -i /root/.ssh/restic-backup -o StrictHostKeyChecking=no restic@truenas.local -s sftp'"
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
