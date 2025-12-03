# Home Manager configuration
{ lib, pkgs, ... }:

{
  home-manager.users.basnijholt =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.stateVersion = "25.05";

      # Tell npm to install "global" packages into ~/.local/npm
      home.file.".npmrc".text = ''
        prefix=${config.home.homeDirectory}/.local/npm
      '';

      # Ensure ~/.local/npm/bin is on PATH for your sessions and user services
      home.sessionPath = [ "${config.home.homeDirectory}/.local/npm/bin" ];

      # Create the directory at activate time (nice-to-have)
      home.activation.ensureNpmGlobalDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${config.home.homeDirectory}/.local/npm"
      '';

    };
}
