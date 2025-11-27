# SLURM high-performance computing configuration
#
# One-time setup: Create munge key with:
#   sudo mkdir -p /etc/munge && sudo dd if=/dev/urandom bs=1 count=1024 | sudo tee /etc/munge/munge.key > /dev/null
#   sudo nixos-rebuild switch
#
# Test with: sinfo, squeue, srun hostname
{ lib, ... }:

{
  # --- Required Directories ---
  systemd.tmpfiles.rules = lib.mkAfter [
    "d /etc/munge 0700 munge munge -"
    "d /var/spool/slurm 0755 slurm slurm -"
    "d /var/spool/slurmd 0755 slurm slurm -"
    "Z /etc/munge/munge.key 0400 munge munge -"
  ];

  # --- Munge Authentication ---
  services.munge = {
    enable = true;
    password = "/etc/munge/munge.key";
  };

  # --- SLURM Cluster ---
  services.slurm = {
    server.enable = true;
    client.enable = true;
    clusterName = "homelab";
    controlMachine = "pc";
    nodeName = [
      "pc CPUs=24 State=UNKNOWN" # Adjust CPUs to match your system
    ];
    partitionName = [
      "cpu Nodes=pc Default=YES MaxTime=INFINITE State=UP"
    ];
    extraConfig = ''
      AccountingStorageType=accounting_storage/none
      JobAcctGatherType=jobacct_gather/none
      ProctrackType=proctrack/cgroup
      ReturnToService=1
      SlurmdSpoolDir=/var/spool/slurmd
    '';
  };
}
