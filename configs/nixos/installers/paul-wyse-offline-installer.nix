# Paul's Wyse 5070 Offline Installer ISO
#
# Build:
#   nix build .#nixosConfigurations.paul-wyse-offline-installer.config.system.build.isoImage
#
# This creates an ISO containing the ENTIRE system closure - no internet needed!
# The ISO will be larger (~2-3GB) but installation works completely offline.
#
# After booting:
#   1. SSH in: ssh root@<ip>  (or use console, password: nixos)
#   2. Run: install-paul-wyse
#   3. Reboot
{ lib, pkgs, modulesPath, targetSystem, diskoModule, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;

  # Path to the pre-built target system
  targetSystemPath = targetSystem.config.system.build.toplevel;

  # Standalone disko config for partitioning
  diskoConfig = ./paul-wyse-disko-standalone.nix;

  # Install script that uses local closure
  installScript = pkgs.writeShellScriptBin "install-paul-wyse" ''
    set -euo pipefail

    echo "=== Paul's Wyse 5070 NixOS Offline Installer ==="
    echo ""

    # Check we're on the right hardware
    if [[ ! -b /dev/mmcblk0 ]]; then
      echo "ERROR: /dev/mmcblk0 not found!"
      echo "This installer is for Dell Wyse 5070 with eMMC storage."
      echo ""
      echo "Available block devices:"
      lsblk
      exit 1
    fi

    echo "Found eMMC at /dev/mmcblk0:"
    lsblk /dev/mmcblk0
    echo ""

    read -p "This will ERASE ALL DATA on /dev/mmcblk0. Continue? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 1
    fi

    echo ""
    echo "=== Step 1/2: Partitioning with disko ==="
    ${diskoModule}/bin/disko --mode destroy,format,mount --yes-wipe-all-disks ${diskoConfig}

    echo ""
    echo "=== Step 2/2: Installing NixOS (offline) ==="
    # Use pre-built system from ISO - no network needed!
    nixos-install --root /mnt --no-root-passwd --system ${targetSystemPath}

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
  image.baseName = lib.mkForce "paul-wyse-offline-installer";

  # CRITICAL: Include the entire target system closure in the ISO
  isoImage.storeContents = [ targetSystemPath ];

  # Include our install script
  environment.systemPackages = [
    installScript
    pkgs.vim
    pkgs.htop
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

    === Paul's Wyse 5070 NixOS OFFLINE Installer ===

    To install, run:  install-paul-wyse

    Or SSH in:  ssh root@<this-ip>  (password: nixos)

    NO INTERNET REQUIRED - full system closure included!

  '';

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" ];
  };

  system.stateVersion = "25.05";
}
