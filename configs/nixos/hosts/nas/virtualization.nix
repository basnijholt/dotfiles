{
  config,
  lib,
  pkgs,
  ...
}:

let
  incus = "${config.virtualisation.incus.package}/bin/incus";
  applyIncusConfig = pkgs.writeShellScriptBin "nas-apply-incus-config" ''
        set -euo pipefail

        if ! ${incus} info >/dev/null 2>&1; then
          echo "Incus is not ready; skipping imported instance configuration"
          exit 0
        fi

        instance_exists() {
          ${incus} info "$1" >/dev/null 2>&1
        }

        set_config() {
          local instance="$1"
          local key="$2"
          local value="$3"
          # Use key=value form: the deprecated "key value" form misparses values
          # that themselves contain "=" (e.g. raw.lxc=lxc.apparmor.profile=unconfined),
          # which aborted this script under set -e and left memory limits unapplied.
          ${incus} config set "$instance" "$key=$value"
        }

        ensure_device() {
          local instance="$1"
          local device="$2"
          local type="$3"
          shift 3

          if ! ${incus} config device show "$instance" | ${pkgs.gnugrep}/bin/grep -q "^$device:"; then
            ${incus} config device add "$instance" "$device" "$type" "$@"
            return
          fi

          local assignment key value
          for assignment in "$@"; do
            key="''${assignment%%=*}"
            value="''${assignment#*=}"
            ${incus} config device set "$instance" "$device" "$key=$value"
          done
        }

        configure_bridged_container() {
          local instance="$1"
          ensure_device "$instance" eth0 nic nictype=bridged parent=br0
          ensure_device "$instance" root disk path=/ pool=ssd
        }

        configure_host_mounts_and_gpu() {
          local instance="$1"
          ensure_device "$instance" disk0 disk path=/mnt/data source=/mnt/ssd/docker/data recursive=true shift=true
          ensure_device "$instance" disk1 disk path=/opt/stacks source=/mnt/ssd/docker/stacks recursive=true shift=true
          ensure_device "$instance" disk2 disk path=/mnt/tank source=/mnt/tank recursive=true
          ensure_device "$instance" gpu gpu gputype=physical pci=0000:00:02.0
        }

        if instance_exists docker; then
          set_config docker boot.autostart true
          set_config docker user.autostart true
          # Cap the main workload LXC (runs ~104 Docker containers; ~22 GiB at
          # normal load) so it cannot exhaust host RAM as it did on TrueNAS.
          set_config docker limits.memory 40GiB
          # Let it swap idle memory into the host's zram (compressed RAM; no swap
          # on ZFS, which can deadlock). It has to be a size: with limits.memory
          # set, "true" means memory+swap <= limit, i.e. no swap at all. Without
          # swap, ~31 GiB of container memory couldn't be paged out and the host
          # OOMed on 2026-09-30.
          set_config docker limits.memory.swap 12GiB
          set_config docker security.nesting true
          set_config docker security.privileged true
          set_config docker security.syscalls.intercept.mount true
          set_config docker raw.lxc "lxc.apparmor.profile=unconfined"
          set_config docker raw.idmap "$(cat <<'EOF'
    uid 568 568
    uid 1000 1000
    gid 568 568
    gid 3000 3000
    gid 3006 3006
    EOF
    )"
          configure_bridged_container docker
          configure_host_mounts_and_gpu docker
        else
          echo "Skipping docker: Incus instance not imported"
        fi

        if instance_exists nix-cache; then
          set_config nix-cache boot.autostart true
          set_config nix-cache user.autostart true
          set_config nix-cache limits.cpu 8
          set_config nix-cache limits.memory 24576MiB
          set_config nix-cache limits.memory.swap true
          set_config nix-cache security.privileged false
          set_config nix-cache raw.idmap "$(cat <<'EOF'
    uid 568 568
    uid 1000 1000
    gid 568 568
    gid 3000 3000
    gid 3006 3006
    EOF
    )"
          configure_bridged_container nix-cache
        else
          echo "Skipping nix-cache: Incus instance not imported"
        fi

        if instance_exists dev-lxc; then
          set_config dev-lxc boot.autostart true
          set_config dev-lxc user.autostart true
          # Coding agents (T3 Code) on spare cores: at most 16 of the 20
          # threads. A 20% allowance sets cpu.weight to 20 against the
          # default 100, so dev-lxc yields to docker and nix-cache under
          # contention but may still use all 16 threads when they idle.
          # (limits.cpu.priority only subtracts 10 - priority from 100.)
          set_config dev-lxc limits.cpu 16
          set_config dev-lxc limits.cpu.allowance 20%
          # Host memory is the NAS's limit (see the docker cap above). Swap
          # must be a size: "true" with limits.memory set means no swap.
          set_config dev-lxc limits.memory 12GiB
          set_config dev-lxc limits.memory.swap 4GiB
          # Docker inside the container, like the mindroom LXC on pc
          set_config dev-lxc security.nesting true
          ensure_device dev-lxc eth0 nic nictype=bridged parent=br0
          ensure_device dev-lxc root disk path=/ pool=ssd size=200GiB
        else
          echo "Skipping dev-lxc: Incus instance not created"
        fi
  '';
in
{
  hardware.graphics.enable = true;

  virtualisation = {
    docker = {
      enable = true;
      daemon.settings = {
        dns = [
          "192.168.1.66"
          "8.8.8.8"
          "192.168.1.240"
        ];
      };
    };

    incus = {
      enable = true;
      preseed = {
        networks = [
          {
            name = "incusbr0";
            type = "bridge";
            config = {
              "ipv4.address" = "10.44.217.1/24";
              "ipv4.nat" = "true";
              "ipv6.address" = "fd42:4417:5b9e:8b0c::1/64";
              "ipv6.nat" = "true";
            };
          }
        ];
        profiles = [
          {
            name = "default";
            config = { };
            devices = {
              eth0 = {
                name = "eth0";
                network = "incusbr0";
                type = "nic";
              };
            };
          }
        ];
        storage_pools = [
          {
            name = "ssd";
            driver = "zfs";
            config = {
              source = "ssd/.ix-virt";
              "zfs.pool_name" = "ssd/.ix-virt";
            };
          }
        ];
      };
    };
    libvirtd.enable = lib.mkForce false;
  };

  users.users.basnijholt.extraGroups = [
    "render"
    "video"
  ];

  # Unprivileged Incus instances with raw.idmap need newuidmap/newgidmap to
  # allow the host IDs passed through above. Incus already adds the large
  # shifted 1000000+ range; these entries cover the explicit passthrough IDs.
  users.users.root = {
    subUidRanges = lib.mkAfter [
      {
        startUid = 568;
        count = 1;
      }
      {
        startUid = 1000;
        count = 1;
      }
    ];
    subGidRanges = lib.mkAfter [
      {
        startGid = 568;
        count = 1;
      }
      {
        startGid = 3000;
        count = 1;
      }
      {
        startGid = 3006;
        count = 1;
      }
    ];
  };

  environment.systemPackages = [ applyIncusConfig ];

  # compose-farm executes stacks inside the Docker Incus container, but parses
  # their labels on this host when regenerating Traefik configuration.
  systemd.tmpfiles.rules = [
    "L+ /opt/stacks - - - - /mnt/ssd/docker/stacks"
  ];

  systemd.services.nas-apply-incus-config = {
    description = "Apply NAS Incus config to imported instances";
    wants = [
      "incus.service"
      "zfs.target"
    ];
    after = [
      "incus.service"
      "incus-preseed.service"
      "zfs.target"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = "${applyIncusConfig}/bin/nas-apply-incus-config";
  };

  systemd.services.incus = {
    wants = [ "zfs.target" ];
    after = [ "zfs.target" ];
  };

  # The keys of the encrypted datasets arrive from the pi4 after boot
  # (zfs-unlock). Incus storage lives on ssd, and the docker instance binds
  # the ssd tree and /mnt/tank, so hold Incus back until every dataset the
  # receiver unlocks is mounted. Otherwise instances autostart against locked
  # datasets, and the media apps act on an empty /mnt/tank/media. Wants
  # rather than Requires, so a restart of this unit never restarts Incus.
  systemd.services.nas-wait-zfs-unlock = {
    description = "Wait for the zfs-unlock datasets to be mounted";
    wants = [ "zfs.target" ];
    after = [ "zfs.target" ];
    before = [ "incus.service" ];
    wantedBy = [ "incus.service" ];
    path = [
      config.boot.zfs.package
      pkgs.gawk
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "infinity";
    };
    # The receiver mounts each subtree parents first, one dataset at a time,
    # so wait for all of ssd's tree. Check only the top of each tank root:
    # tank/backups' replication targets can hold a dataset that never mounts.
    # The gate therefore does not cover the docker instance's B2 job, which
    # reads tank/backups' ssd mirror.
    script = ''
      # ready ROOT SCOPE: ROOT exists, its key is loaded, and every dataset in
      # SCOPE (zfs list depth flags) that should be mounted is.
      ready() {
        rows=$(zfs list -H -o canmount,mountpoint,mounted $2 "$1" 2>/dev/null) &&
          [ "$(zfs get -H -o value keystatus "$1")" != unavailable ] &&
          [ -z "$(printf '%s\n' "$rows" |
            awk -F'\t' '$1 == "on" && $2 != "legacy" && $2 != "none" && $3 != "yes"')" ]
      }
      for root in ${lib.escapeShellArgs config.services.zfs-unlock.receiver.datasets}; do
        if [ "$root" = ssd ]; then scope=-r; else scope="-d 0"; fi
        echo "waiting for $root"
        until ready "$root" "$scope"; do
          sleep 5
        done
      done
    '';
  };
}
