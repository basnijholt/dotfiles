{ lib, pkgs, ... }:

let
  sshKeys = (import ../../common/ssh-keys.nix).sshKeys;
in
{
  imports = [
    ./networking.nix
  ];

  system.stateVersion = "25.05";
  networking.hostName = lib.mkForce "hetzner-saas";

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "basnijholt"
    ];
    fallback = true;
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    max-jobs = 1;
    cores = 2;
  };

  users.users.basnijholt = {
    isNormalUser = true;
    description = "Bas Nijholt";
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = sshKeys;
  };
  users.users.root.openssh.authorizedKeys.keys = sshKeys;
  security.sudo.wheelNeedsPassword = false;

  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = lib.mkForce "prohibit-password";
      UseDns = lib.mkForce false;
    };
  };

  services.earlyoom = {
    enable = true;
    freeSwapThreshold = 10;
    freeMemThreshold = 10;
  };

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable=traefik"
      "--write-kubeconfig-mode=0644"
    ];
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    jq
    kubectl
    kubernetes-helm
    k9s
    ripgrep
    vim
  ];

  virtualisation.docker.enable = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  systemd.services."systemd-zram-setup@zram0".restartIfChanged = false;

  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "kernel.sysrq" = 1;
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
