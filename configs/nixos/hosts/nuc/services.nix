{ pkgs, lib, ... }:

let
  inherit (lib) mkDefault;
in
{
  services.tailscale.enable = mkDefault true;
  services.syncthing.enable = mkDefault true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      X11Forwarding = false;
    };
  };

  # Container & VM stack for swarm workloads.
  virtualisation = {
    docker.enable = true;
    incus.enable = true;
  };

  # Provide firmware updates even on the appliance box.
  services.fwupd.enable = mkDefault true;

  # 1Password / printing are intentionally omitted here.
}
