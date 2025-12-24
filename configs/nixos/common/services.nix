# System services shared by all hosts
{ pkgs, ... }:

{
  services.fwupd.enable = true;
  services.syncthing.enable = true;
  services.tailscale.enable = true;

  # --- System Stability ---
  services.earlyoom = {
    enable = true;
    freeSwapThreshold = 2;
    freeMemThreshold = 2;
  };

  # --- SSH ---
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      UseDns = false;
      X11Forwarding = true;
    };
  };

  # --- Mosh ---
  programs.mosh.enable = true;

  # --- Security & Authentication ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # pinentryPackage is set in optional/desktop.nix (requires GUI)
  };

  # --- Known Hosts ---
  programs.ssh.knownHosts = {
    "truenas.local" = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBFtTkkcsQ1KKBJ1ne2Q2COhfBSxs3H0ppO/HEirJt4";
    };
  };
}
