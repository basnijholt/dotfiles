{ lib, pkgs, ... }:

{
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
  ];

  networking.firewall = {
    trustedInterfaces = [ "cni0" "flannel.1" ];
    allowedTCPPorts = lib.mkForce (
      [ 22 80 443 6443 ]
      ++ [ 20 21 ]
      ++ (lib.range 21100 21110)
    );
    allowedUDPPorts = [ 8472 ];
  };
}
