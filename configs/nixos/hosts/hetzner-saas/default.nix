{ lib, pkgs, ... }:

{
  imports = [
    ../../optional/zfs-auto-snapshot.nix
    ./networking.nix
  ];

  networking.hostName = lib.mkForce "hetzner-saas";

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable=traefik"
      "--write-kubeconfig-mode=0644"
    ];
  };

  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    k9s
  ];

  virtualisation.docker.enable = true;

  services.fwupd.enable = lib.mkForce false;
  services.syncthing.enable = lib.mkForce false;

  services.openssh.settings = {
    UseDns = lib.mkForce false;
    PermitRootLogin = lib.mkForce "prohibit-password";
  };

  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];
  nix.settings.max-jobs = 1;
  nix.settings.cores = 2;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  systemd.services."systemd-zram-setup@zram0".restartIfChanged = false;

  networking.hostId = "5d9d75a1";
}
