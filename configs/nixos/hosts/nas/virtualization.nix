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
          ${incus} config set "$instance" "$key" "$value"
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
            ${incus} config device set "$instance" "$device" "$key" "$value"
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
          set_config docker user.autostart true
          # Cap container RAM so a runaway cannot exhaust the host (the original
          # TrueNAS OOM death-spiral). Hard limit; the in-container OOM killer
          # acts before the host does.
          set_config docker limits.memory 6GiB
          set_config docker security.nesting true
          set_config docker security.privileged true
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

        if instance_exists nixos; then
          set_config nixos user.autostart true
          # Cap the big workload LXC (runs ~104 Docker containers; ~22 GiB at
          # normal load) so it cannot exhaust host RAM as it did on TrueNAS.
          set_config nixos limits.memory 40GiB
          set_config nixos security.nesting true
          set_config nixos security.privileged true
          set_config nixos security.syscalls.intercept.mount true
          set_config nixos raw.lxc "lxc.apparmor.profile=unconfined"
          set_config nixos raw.idmap "$(cat <<'EOF'
    uid 568 568
    uid 1000 1000
    gid 568 568
    gid 3000 3000
    gid 3006 3006
    EOF
    )"
          configure_bridged_container nixos
          configure_host_mounts_and_gpu nixos
        else
          echo "Skipping nixos: Incus instance not imported"
        fi

        if instance_exists nix-cache; then
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

  environment.systemPackages = [ applyIncusConfig ];

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
}
