# Container configuration for Incus LXC (not VM)
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

  # --- Fix LoadCredential in LXC containers ---
  # See: https://github.com/NixOS/nixpkgs/issues/157449
  boot.specialFileSystems."/run".options = [ "rshared" ];

  # --- Enable systemd-resolved for .local DNS resolution ---
  # LXC containers default to useHostResolvConf=true which conflicts with
  # systemd-resolved. We enable resolved and disable host resolv.conf.
  services.resolved.enable = true;
  networking.useHostResolvConf = lib.mkForce false;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
