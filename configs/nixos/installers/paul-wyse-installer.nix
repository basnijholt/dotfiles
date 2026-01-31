# Paul's Wyse 5070 Installer ISO
#
# Build:
#   nix build .#nixosConfigurations.paul-wyse-installer.config.system.build.isoImage
#
# This creates an ISO that boots with SSH enabled and includes an install script.
# Requires internet connection for installation.
#
# After booting:
#   1. SSH in: ssh root@<ip>  (or use console, password: nixos)
#   2. Run: install-paul-wyse
#   3. Reboot
{ lib, pkgs, modulesPath, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;

  # Install script - works reliably on 4GB USB + 4GB RAM systems
  # Key fixes:
  #   1. Manual partition (avoids flake fetch that fills tiny USB overlay)
  #   2. Set TMPDIR to eMMC (Nix temp files go to 29GB disk, not 2GB overlay)
  #   3. Create swap before install (prevents OOM during Rust builds)
  #   4. Use --max-jobs 1 (limits memory usage for low-RAM system)
  installScript = pkgs.writeShellScriptBin "install-paul-wyse" ''
    set -euo pipefail

    DISK="/dev/mmcblk0"

    echo "=== Paul's Wyse 5070 NixOS Installer ==="
    echo ""

    # Check we're on the right hardware
    if [[ ! -b "$DISK" ]]; then
      echo "ERROR: $DISK not found!"
      echo "This installer is for Dell Wyse 5070 with eMMC storage."
      echo ""
      echo "Available block devices:"
      lsblk
      exit 1
    fi

    echo "Found eMMC at $DISK:"
    lsblk "$DISK"
    echo ""

    read -p "This will ERASE ALL DATA on $DISK. Continue? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 1
    fi

    echo ""
    echo "=== Step 1/5: Partitioning ==="
    # Wipe existing
    zpool destroy zroot 2>/dev/null || true
    wipefs -af "$DISK"
    sgdisk --zap-all "$DISK"

    # Create GPT: 512M ESP + rest for ZFS
    sgdisk -n1:1M:+512M -t1:EF00 -c1:ESP-PWYSE "$DISK"
    sgdisk -n2:0:0 -t2:BF00 -c2:zfs "$DISK"
    partprobe "$DISK"
    sleep 2

    # Format ESP
    mkfs.vfat -F32 -n ESP-PWYSE "''${DISK}p1"

    # Create ZFS pool
    echo ""
    echo "=== Step 2/5: Creating ZFS pool ==="
    zpool create -f \
      -o ashift=12 \
      -o autotrim=on \
      -O compression=zstd \
      -O acltype=posixacl \
      -O xattr=sa \
      -O atime=off \
      -O mountpoint=none \
      zroot "''${DISK}p2"

    # Create datasets
    zfs create -o mountpoint=legacy zroot/root
    zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=false zroot/nix
    zfs create -o mountpoint=legacy zroot/var
    zfs create -o mountpoint=legacy zroot/home

    # Create swap zvol (prevents OOM during builds)
    zfs create -V 4G zroot/swap

    echo ""
    echo "=== Step 3/5: Mounting filesystems ==="
    mount -t zfs zroot/root /mnt
    mkdir -p /mnt/{boot,nix,var,home}
    mount -t zfs zroot/nix /mnt/nix
    mount -t zfs zroot/var /mnt/var
    mount -t zfs zroot/home /mnt/home
    mount "''${DISK}p1" /mnt/boot

    echo ""
    echo "=== Step 4/5: Enabling swap ==="
    # Wait for zvol device to appear
    udevadm trigger
    sleep 2
    mkswap /dev/zvol/zroot/swap
    swapon /dev/zvol/zroot/swap
    echo "Swap enabled: $(free -h | grep Swap)"

    # Redirect temp to eMMC (not tiny USB overlay)
    mkdir -p /mnt/tmp/nix-build
    export TMPDIR=/mnt/tmp/nix-build

    echo ""
    echo "=== Step 5/5: Installing NixOS ==="
    nixos-install --root /mnt --no-root-passwd \
      --max-jobs 1 --cores 2 \
      --option substituters "https://cache.nixos.org https://nix-community.cachix.org" \
      --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" \
      --flake github:basnijholt/dotfiles/main?dir=configs/nixos#paul-wyse

    # Cleanup
    rm -rf /mnt/tmp/nix-build
    swapoff /dev/zvol/zroot/swap

    echo ""
    echo "=== Installation complete! ==="
    echo ""
    echo "Next steps:"
    echo "  1. Reboot: reboot"
    echo "  2. Login as basnijholt (password: nixos)"
    echo "  3. Change password: passwd"
    echo "  4. Connect Tailscale: sudo tailscale up --login-server https://headscale.nijho.lt"
    echo "  5. Point router DNS at this machine's IP"
    echo ""
  '';
in
{
  # Start from minimal installer
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # Identify this ISO
  image.fileName = lib.mkForce "paul-wyse-installer.iso";

  # Include our install script (partitioning tools come from minimal installer)
  environment.systemPackages = with pkgs; [
    installScript
    git
    vim
    htop
  ];

  # SSH access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  users.users.root = {
    initialPassword = "nixos";
    openssh.authorizedKeys.keys = sshKeys;
  };

  # Show install instructions on console
  services.getty.helpLine = lib.mkForce ''

    === Paul's Wyse 5070 NixOS Installer ===

    To install, run:  install-paul-wyse

    Or SSH in:  ssh root@<this-ip>  (password: nixos)

    NOTE: Requires internet connection.

  '';

  # Nix settings for installation
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" ];
  };

  system.stateVersion = "25.05";
}
