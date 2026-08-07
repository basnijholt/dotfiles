{ lib, pkgs, ... }:

let
  # Guest udev rules do not expose the attachment name on NVMe, so address the
  # raw node. The work disk is always the second namespace.
  workDevice = "/dev/nvme0n2";
  mapperName = "agent-work";
  mapperDevice = "/dev/mapper/${mapperName}";
  mountPoint = "/work";

  workDisk = pkgs.writeShellApplication {
    name = "agent-work-disk";
    runtimeInputs = with pkgs; [
      cryptsetup
      e2fsprogs
      gnugrep
      util-linux
    ];
    text = ''
      set -euo pipefail

      if [ "$(id -u)" -ne 0 ]; then
        echo "run as root: sudo agent-work-disk ''${1:-}" >&2
        exit 1
      fi

      case "''${1:-}" in
        unlock)
          if [ ! -b "${workDevice}" ]; then
            echo "work disk not found at ${workDevice}" >&2
            exit 1
          fi

          if [ ! -b "${mapperDevice}" ]; then
            if ! cryptsetup isLuks "${workDevice}"; then
              if wipefs -n "${workDevice}" | grep -q .; then
                echo "refusing to format non-empty disk ${workDevice}" >&2
                wipefs -n "${workDevice}" >&2
                exit 1
              fi
              echo "${workDevice} is empty and will become an encrypted LUKS2 work disk."
              read -r -p "Type FORMAT to continue: " confirmation
              [ "$confirmation" = "FORMAT" ] || exit 1
              cryptsetup luksFormat --type luks2 "${workDevice}"
            fi
            cryptsetup open "${workDevice}" "${mapperName}"
          fi

          filesystem_type="$(blkid -p -s TYPE -o value "${mapperDevice}" || true)"
          case "$filesystem_type" in
            "") mkfs.ext4 -L agent-work "${mapperDevice}" ;;
            ext4) ;;
            *)
              echo "refusing unexpected filesystem $filesystem_type on ${mapperDevice}" >&2
              exit 1
              ;;
          esac

          mkdir -p "${mountPoint}"
          mountpoint -q "${mountPoint}" || mount "${mapperDevice}" "${mountPoint}"
          chown basnijholt:users "${mountPoint}"
          chmod 0700 "${mountPoint}"
          echo "${mapperDevice} mounted at ${mountPoint}"
          ;;
        lock)
          mountpoint -q "${mountPoint}" && umount "${mountPoint}"
          [ ! -b "${mapperDevice}" ] || cryptsetup close "${mapperName}"
          ;;
        *)
          echo "usage: agent-work-disk {unlock|lock}" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  imports = [
    ../../optional/large-packages.nix
    ../../optional/virtualization.nix
    ./networking.nix
  ];

  environment.systemPackages = with pkgs; [
    cryptsetup
    google-cloud-sdk
    uv
    workDisk
  ];

  # Link-local addresses on container veths steal the 169.254.0.0/16 route and
  # hide the metadata endpoint, which breaks DNS and host key publishing.
  networking.dhcpcd.denyInterfaces = [
    "veth*"
    "docker*"
    "br-*"
    "incusbr*"
  ];

  # Coding agents may legitimately consume most memory. Avoid killing them
  # while plenty of RAM remains, but retain a last-resort OOM safety margin.
  services.earlyoom.freeMemThreshold = lib.mkForce 3;
  services.earlyoom.freeSwapThreshold = lib.mkForce 3;

  # Keep the encrypted work disk fully manual. Neither boot nor systemd stores
  # its passphrase. The helper creates and owns this otherwise-empty directory.
  systemd.tmpfiles.rules = [ "d ${mountPoint} 0700 basnijholt users - -" ];

  # The first Home Manager activation clones the public dotfiles repository.
  systemd.services.home-manager-basnijholt = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

}
