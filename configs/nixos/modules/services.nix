{ pkgs, ... }:

{
  # ===================================
  # Shared System Services
  # ===================================
  services.fwupd.enable = true;
  services.syncthing.enable = true;
  services.tailscale.enable = true;
  services.printing.enable = true;
  programs.thunderbird.enable = true;

  # --- Virtualisation Stack ---
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.incus.enable = true;
  programs.virt-manager.enable = true;

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
