{ lib, ... }:

{
  # --- SLURM High-Performance Computing ---
  # One-time setup: Create munge key with:
  # sudo mkdir -p /etc/munge && sudo dd if=/dev/urandom bs=1 count=1024 | sudo tee /etc/munge/munge.key > /dev/null
  # Then: sudo nixos-rebuild switch
  #
  # Test with: sinfo, squeue, srun hostname
  # Create required directories with proper permissions
  systemd.tmpfiles.rules = lib.mkAfter [
    "d /etc/munge 0700 munge munge -"
    "d /var/spool/slurm 0755 slurm slurm -"
    "d /var/spool/slurmd 0755 slurm slurm -"
    "Z /etc/munge/munge.key 0400 munge munge -"
  ];

  services.munge = {
    enable = true;
    password = "/etc/munge/munge.key";
  };

  services.slurm = {
    server.enable = true;
    client.enable = true;
    clusterName = "homelab";
    controlMachine = "nixos";
    nodeName = [
      "nixos CPUs=24 State=UNKNOWN" # Adjust CPUs to match your system
    ];
    partitionName = [
      "cpu Nodes=nixos Default=YES MaxTime=INFINITE State=UP"
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
