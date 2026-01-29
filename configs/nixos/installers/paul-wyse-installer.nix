# Paul's Wyse 5070 Installer ISO
#
# Build:
#   nix build .#nixosConfigurations.paul-wyse-installer.config.system.build.isoImage
#
# This creates an ISO that boots with SSH enabled and includes an install script.
# After booting:
#   1. SSH in: ssh root@<ip>  (or use console, password: nixos)
#   2. Run: install-paul-wyse
#   3. Reboot
{ lib, pkgs, modulesPath, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;

  # Install script that does everything
  installScript = pkgs.writeShellScriptBin "install-paul-wyse" ''
    set -euo pipefail

    echo "=== Paul's Wyse 5070 NixOS Installer ==="
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
    echo "=== Step 1/3: Partitioning with disko ==="
    nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
      --mode destroy,format,mount --yes-wipe-all-disks \
      --flake github:basnijholt/dotfiles/paul-wyse-host?dir=configs/nixos#paul-wyse

    echo ""
    echo "=== Step 2/3: Generating hardware config ==="
    # Generate and capture actual hardware config
    nixos-generate-config --root /mnt --show-hardware-config > /tmp/hw-config.nix
    echo "Hardware config generated. Key modules detected:"
    grep -E "availableKernelModules|kernelModules" /tmp/hw-config.nix || true

    echo ""
    echo "=== Step 3/3: Installing NixOS ==="
    nixos-install --root /mnt --no-root-passwd \
      --flake github:basnijholt/dotfiles/paul-wyse-host?dir=configs/nixos#paul-wyse

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

  # Include our install script
  environment.systemPackages = with pkgs; [
    installScript
    git
    vim
    htop
    parted
    gptfdisk
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

  '';

  # Nix settings for installation
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" ];
  };

  system.stateVersion = "25.05";
}
