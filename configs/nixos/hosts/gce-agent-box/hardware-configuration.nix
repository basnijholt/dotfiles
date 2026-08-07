{ lib, modulesPath, ... }:

{
  # Nixpkgs supplies GCE boot, guest-agent, serial-console, and OS Login support.
  imports = [ (modulesPath + "/virtualisation/google-compute-config.nix") ];

  # google-compute-config's legacy singular device and disko both add a target.
  # Keep one canonical GRUB target so mirroredBoots contains no duplicate.
  boot.loader.grub.device = lib.mkForce "";
  boot.loader.grub.devices = lib.mkForce [
    "/dev/disk/by-id/google-agent-boot"
  ];

  # Disko mounts by stable GPT partition label; override the image module's
  # filesystem-label assumption used only for prebuilt GCE images.
  fileSystems."/".device = lib.mkForce "/dev/disk/by-partlabel/disk-main-root";

  # Keep the declared basnijholt account and Home Manager profile authoritative.
  # Cloud IAM still protects the IAP tunnel; the VM accepts the declared SSH key.
  security.googleOsLogin.enable = lib.mkForce false;

  nixpkgs.hostPlatform = "x86_64-linux";
}
