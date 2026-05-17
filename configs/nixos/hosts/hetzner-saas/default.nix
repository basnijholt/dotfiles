{ lib, pkgs, ... }:

let
  sshKeys = (import ../../common/ssh-keys.nix).sshKeys;
  kubeconfig = "/etc/rancher/k3s/k3s.yaml";
  hcloudTokenFile = "/var/lib/mindroom-saas/hcloud-token";
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
    autoDeployCharts = {
      ingress-nginx = {
        repo = "https://kubernetes.github.io/ingress-nginx";
        name = "ingress-nginx";
        version = "4.15.1";
        hash = "sha256-Pv8L0YFR1uaxxEFGNBBXFEPdoax4KSyxiTRmKN54Tww=";
        targetNamespace = "ingress-nginx";
        createNamespace = true;
        values = {
          controller.service = {
            type = "LoadBalancer";
            externalTrafficPolicy = "Local";
          };
        };
      };
      cert-manager = {
        repo = "https://charts.jetstack.io";
        name = "cert-manager";
        version = "v1.20.2";
        hash = "sha256-0qUL1EoJ2DjCV2qPPfyhUkWXxzk8+Ngqs+yKRlue63k=";
        targetNamespace = "cert-manager";
        createNamespace = true;
        values.crds.enabled = true;
      };
      hcloud-csi = {
        repo = "https://charts.hetzner.cloud";
        name = "hcloud-csi";
        version = "2.21.0";
        hash = "sha256-48vH+NR3wrYOlevXyopkmwuvOnT5Yv2ip4NAzYV9wd8=";
        targetNamespace = "kube-system";
        values = {
          controller.hcloudVolumeDefaultLocation = "hel1";
          storageClasses = [{
            name = "hcloud-volumes";
            defaultStorageClass = false;
            reclaimPolicy = "Delete";
            annotations = { };
            extraParameters = { };
          }];
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/mindroom-saas 0700 root root -"
  ];

  systemd.services.mindroom-saas-hcloud-secret = {
    description = "Create hcloud Secret for the Hetzner CSI driver";
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      k3s
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -s "${hcloudTokenFile}" ]; then
        echo "Skipping hcloud Secret creation; ${hcloudTokenFile} is missing"
        exit 0
      fi

      export KUBECONFIG="${kubeconfig}"
      until k3s kubectl get namespace kube-system >/dev/null 2>&1; do
        sleep 2
      done

      k3s kubectl -n kube-system create secret generic hcloud \
        --from-file=token="${hcloudTokenFile}" \
        --dry-run=client \
        -o yaml \
        | k3s kubectl apply -f -
    '';
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
