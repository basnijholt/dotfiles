{ pkgs, ... }:

{
  # ===================================
  # Shared System Services
  # ===================================
  services.fwupd.enable = true;
  services.syncthing.enable = true;
  services.tailscale.enable = true;

  # --- SSH ---
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      UseDns = true;
      X11Forwarding = true;
    };
  };

  # --- Security & Authentication ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
}
