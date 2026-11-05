# Google Compute Engine VM (x86_64): big dev box for coding agents.
#
# Cloud resources live outside this repository. Installed with nixos-anywhere
# from a stock Debian image; after that comin deploys it like any other host.
{ lib, ... }:

let
  sshKeys = (import ../../common/ssh-keys.nix).sshKeys;
in
{
  imports = [
    ../../optional/large-packages.nix
    ../../optional/virtualization.nix
    ./agent-work-disk.nix
    ./networking.nix
  ];

  # Cloud overrides of the common stack (no LAN cache).
  nix.settings = {
    substituters = lib.mkForce [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = lib.mkForce [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  # No physical firmware to update on a VM.
  services.fwupd.enable = lib.mkForce false;

  # Coding agents run here, so treat the box as untrusted: sshd refuses
  # agent/X11 forwarding so it can never borrow a client's keys or display.
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "prohibit-password";
    AllowAgentForwarding = false;
    X11Forwarding = lib.mkForce false;
  };
  services.syncthing.enable = lib.mkForce false;

  # Root key access for nixos-anywhere reinstalls.
  users.users.root.openssh.authorizedKeys.keys = sshKeys;
  security.sudo.wheelNeedsPassword = false;

  # Without swap a full box thrashes page cache instead of OOM-killing.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # Never restart zram on switch; see hosts/hetzner/default.nix.
  systemd.units."systemd-zram-setup@zram0.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      X-RestartIfChanged=false
      X-StopIfChanged=false
    '';
  };

  services.earlyoom.freeMemThreshold = lib.mkForce 5;
  services.earlyoom.freeSwapThreshold = lib.mkForce 10;

  # Cap agents so a runaway leaves headroom for sshd, dockerd and tailscale.
  systemd.slices.user = {
    overrideStrategy = "asDropin";
    sliceConfig = {
      MemoryMax = "85%";
      MemorySwapMax = "48G";
    };
  };

  # The first Home Manager activation clones the public dotfiles repository.
  systemd.services.home-manager-basnijholt = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
