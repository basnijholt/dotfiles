# System services shared by all hosts
{ pkgs, ... }:

{
  services.fwupd.enable = true;
  services.syncthing.enable = true;
  services.tailscale.enable = true;

  # --- SSH ---
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      UseDns = true;
      X11Forwarding = true;
    };
  };

  # --- Security & Authentication ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # pinentryPackage is set in optional/desktop.nix (requires GUI)
  };
}
