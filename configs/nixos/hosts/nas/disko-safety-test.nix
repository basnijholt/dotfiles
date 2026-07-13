{
  pkgs,
  nasDiskoDevice,
  nasDiskoScript,
}:

pkgs.testers.runNixOSTest (
  { lib, ... }:
  {
    name = "nas-disko-safety";

    nodes.machine =
      { pkgs, ... }:
      {
        boot.supportedFilesystems = [ "zfs" ];
        networking.hostId = "8425e349";

        environment.systemPackages = with pkgs; [
          coreutils
          gawk
          gptfdisk
          parted
          util-linux
          zfs
        ];

        virtualisation.emptyDiskImages = [
          2048
          2048
          2048
          2048
        ];
        virtualisation.memorySize = 2048;
      };

    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("modprobe zfs")
      machine.succeed("""
        set -euo pipefail

        for dev in /dev/vdb /dev/vdc /dev/vdd /dev/vde; do
          test -b "$dev"
        done

        # Simulate the current boot disk: disko is expected to destroy this.
        zpool create -f boot-pool /dev/vdb
        zfs create boot-pool/root
        zpool export boot-pool

        # Simulate imported-by-name data pools that must survive disko.
        zpool create -f -O mountpoint=/mnt/tank tank mirror /dev/vdc /dev/vdd
        zfs create tank/sentinel
        printf 'tank-ok\\n' > /mnt/tank/sentinel/sentinel.txt

        zpool create -f -O mountpoint=/mnt/ssd ssd /dev/vde
        zfs create ssd/sentinel
        printf 'ssd-ok\\n' > /mnt/ssd/sentinel/sentinel.txt

        sync
        zpool export tank
        zpool export ssd
        udevadm settle

        zdb -l /dev/vdc1 | grep -q "name: 'tank'"
        zdb -l /dev/vdd1 | grep -q "name: 'tank'"
        zdb -l /dev/vde1 | grep -q "name: 'ssd'"

        byid=${pkgs.lib.escapeShellArg nasDiskoDevice}
        mkdir -p /dev/disk/by-id
        ln -sfn /dev/vdb "$byid"

        # The generated disko script expects normal by-id partition symlinks.
        # The VM uses virtio disks, so mirror the symlinks as partitions appear.
        (
          while true; do
            if [ -b /dev/vdb1 ]; then
              ln -sfn /dev/vdb1 "$byid-part1"
            fi
            if [ -b /dev/vdb2 ]; then
              ln -sfn /dev/vdb2 "$byid-part2"
            fi
            sleep 0.1
          done
        ) &
        linker_pid="$!"
        trap 'kill "$linker_pid" >/dev/null 2>&1 || true' EXIT

        ${nasDiskoScript}

        udevadm settle
        zdb -l /dev/vdb2 | grep -q "name: 'zroot'"
        for dev in /dev/vdb /dev/vdb1 /dev/vdb2; do
          zdb -l "$dev" 2>/dev/null || true
        done > /tmp/disko-target-labels
        if grep -Eq "name: '(tank|ssd)'" /tmp/disko-target-labels; then
          echo "data-pool label found on disko target"
          exit 1
        fi

        zdb -l /dev/vdc1 | grep -q "name: 'tank'"
        zdb -l /dev/vdd1 | grep -q "name: 'tank'"
        zdb -l /dev/vde1 | grep -q "name: 'ssd'"

        zpool import tank
        zpool import ssd

        test "$(cat /mnt/tank/sentinel/sentinel.txt)" = "tank-ok"
        test "$(cat /mnt/ssd/sentinel/sentinel.txt)" = "ssd-ok"
      """)
    '';
  }
)
