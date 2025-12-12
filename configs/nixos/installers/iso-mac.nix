# Installer ISO configuration
# SSH is enabled with key-only auth; root login allowed but NO passwords.
{ pkgs, nixos-hardware, ... }:

let
  sshKeys = (import ../common/ssh-keys.nix).sshKeys;
in
{
  imports = [
    nixos-hardware.nixosModules.apple-t2
    ../hosts/macbook-air-intel/apple-t2.nix
    ../common/nix.nix
  ];

  # Use NetworkManager for WiFi (allows manual connection)
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager = {
    enable = true;
    plugins = lib.mkForce []; # Minimal plugins to save space
  };

  # Improve WiFi support (Broadcom firmware)
  hardware.enableRedistributableFirmware = true;
  # Allow unfree packages (Broadcom drivers) - strictly required for T2 WiFi
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

  # Dependencies for get-apple-firmware (Option 2/3)
  environment.systemPackages = with pkgs; [
    git
    python3
    p7zip
    dmg2img
  ];

  # Fix for get-apple-firmware: Make /lib/firmware writable using an overlay
  # This allows the script to extract drivers into the read-only ISO environment.
  systemd.services.make-firmware-writable = {
    description = "Make /lib/firmware writable for WiFi driver extraction";
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ util-linux coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /tmp/fw-upper /tmp/fw-work
      mount -t overlay overlay -o lowerdir=/lib/firmware,upperdir=/tmp/fw-upper,workdir=/tmp/fw-work /lib/firmware
      mkdir -p /lib/firmware/brcm
    '';
  };
}
