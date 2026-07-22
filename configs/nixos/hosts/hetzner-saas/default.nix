# Hetzner Cloud VPS (x86_64) - single-node K3s host for MindRoom SaaS.
#
# Uses mkHost since the 2026-07 ZFS reinstall, so the common stack
# (user, packages, tailscale, comin GitOps, disk-cleanup) comes from
# common/; this file only keeps cloud overrides and the k3s workload.
# The NAS pulls this host's backups; see hosts/nas/replication.nix.
{ lib, pkgs, ... }:

let
  sshKeys = (import ../../common/ssh-keys.nix).sshKeys;
  kubeconfig = "/etc/rancher/k3s/k3s.yaml";
  hcloudTokenFile = "/var/lib/mindroom-saas/hcloud-token";
in
{
  imports = [
    ../../optional/zfs-sanoid.nix
    ./networking.nix
  ];

  system.stateVersion = "25.05";

  # Required for ZFS
  networking.hostId = "5aa5c0de";

  # Cloud overrides of the common stack (no LAN cache, no reverse DNS).
  nix.settings = {
    substituters = lib.mkForce [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = lib.mkForce [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    max-jobs = 1;
    cores = 2;
  };

  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "prohibit-password";
    UseDns = lib.mkForce false;
  };

  # Root key access: nixos-anywhere installs, manual deploys, and the NAS
  # backup pull all connect as root.
  users.users.root.openssh.authorizedKeys.keys = sshKeys;
  security.sudo.wheelNeedsPassword = false;

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

      token="$(tr -cd '[:alnum:]' < "${hcloudTokenFile}")"
      if [ "''${#token}" -ne 64 ]; then
        echo "Skipping hcloud Secret creation; sanitized token length is ''${#token}, expected 64"
        exit 1
      fi

      k3s kubectl -n kube-system create secret generic hcloud \
        --from-literal=token="$token" \
        --dry-run=client \
        -o yaml \
        | k3s kubectl apply -f -
    '';
  };

  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    k9s
  ];

  virtualisation.docker.enable = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  # Keep the generated zram instance untouched during switch-to-configuration.
  # This must be a drop-in: a concrete systemd-zram-setup@zram0.service would
  # shadow zram-generator's unit and boot without zram swap.
  # Do not use systemd.services."systemd-zram-setup@zram0" here: that creates
  # the concrete unit and can reproduce the no-ExecStart/OOM failure mode.
  systemd.units."systemd-zram-setup@zram0.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      X-RestartIfChanged=false
      X-StopIfChanged=false
    '';
  };

  # bbr + sysrq sysctls and the tcp_bbr module come from common/core.nix.
}
