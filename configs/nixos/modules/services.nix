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
  virtualisation.incus.preseed = {
    config = { };
    networks = [
      {
        config = {
          "ipv4.address" = "auto";
          "ipv6.address" = "auto";
        };
        description = "Default incus network";
        name = "incusbr0";
        type = "bridge";
        project = "default";
      }
    ];
    storage_pools = [
      {
        config = {
          source = "/var/lib/incus/storage-pools/default";
        };
        description = "Default storage pool";
        name = "default";
        driver = "dir";
      }
    ];
    profiles = [
      {
        config = { };
        description = "Default Incus profile";
        devices = {
          eth0 = {
            name = "eth0";
            network = "incusbr0";
            type = "nic";
          };
          root = {
            path = "/";
            pool = "default";
            type = "disk";
          };
        };
        name = "default";
      }
    ];
  };
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
