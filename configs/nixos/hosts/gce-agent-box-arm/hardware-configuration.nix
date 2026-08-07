{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/virtualisation/google-compute-config.nix") ];

  # Arm instances have no CSM; boot from the ESP instead of GRUB.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Disko mounts by stable GPT partition label.
  fileSystems."/".device = lib.mkForce "/dev/disk/by-partlabel/disk-main-root";

  # Keep the declared account and Home Manager profile authoritative.
  security.googleOsLogin.enable = lib.mkForce false;

  nixpkgs.hostPlatform = "aarch64-linux";
}
