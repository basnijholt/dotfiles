# Container configuration for Incus (not VM)
{ lib, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/virtualisation/lxc-container.nix")
    ];

  # --- Container Boot (no bootloader, uses host kernel) ---
  boot.isContainer = true;

  # --- File Systems (managed by Incus, appears as simple rootfs) ---
  fileSystems."/" = {
    device = "rootfs";
    fsType = "none";
    options = [ "defaults" ];
  };

  # --- Disable systemd-resolved (container uses host DNS) ---
  services.resolved.enable = lib.mkForce false;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
