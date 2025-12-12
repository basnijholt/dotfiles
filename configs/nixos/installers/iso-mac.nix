# Installer ISO configuration
# SSH is enabled with key-only auth; root login allowed but NO passwords.
{ pkgs, lib, nixos-hardware, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;
in
{
  imports = [
    nixos-hardware.nixosModules.apple-t2
    ../optional/apple-t2.nix
  ] ++ lib.optional (builtins.pathExists ../hosts/macbook-air-intel/wifi.nix) ../hosts/macbook-air-intel/wifi.nix;

  # Use NetworkManager for WiFi (allows pre-configuring profiles via wifi.nix)
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager = {
    enable = true;
    plugins = lib.mkForce []; # Minimal plugins to save space
  };

  # Improve WiFi support (Broadcom firmware)
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  users.users.root = {
    initialPassword = "nixos"; # default console password
    openssh.authorizedKeys.keys = sshKeys;
  };

  # Fix for get-apple-firmware: Make /lib/firmware writable using an overlay
  # This allows the script to extract drivers into the read-only ISO environment.
  systemd.services.make-firmware-writable = {
    description = "Make /lib/firmware writable for WiFi driver extraction";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /tmp/fw-upper /tmp/fw-work
      mount -t overlay overlay -o lowerdir=/lib/firmware,upperdir=/tmp/fw-upper,workdir=/tmp/fw-work /lib/firmware
    '';
  };
}
