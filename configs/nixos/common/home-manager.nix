{ pkgs, lib, config, ... }:

{
  # ===================================
  # Home Manager Configuration
  # ===================================
  home-manager.users.basnijholt =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      # --- Mechabar Dependencies ---
      home.packages = with pkgs; [
        bluetui
        bluez
        brightnessctl
        pipewire
        wireplumber
        rofi
      ];

      home.stateVersion = "25.05";

      # Tell npm to install "global" packages into ~/.npm-global
      home.file.".npmrc".text = ''
        prefix=${config.home.homeDirectory}/.npm-global
      '';

      # Ensure ~/.npm-global/bin is on PATH for your sessions and user services
      home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

      # Create the directory at activate time (nice-to-have)
      home.activation.ensureNpmGlobalDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${config.home.homeDirectory}/.npm-global"
      '';

    };
}
