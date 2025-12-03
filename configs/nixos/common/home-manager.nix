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

      # Create the directory at activate time (nice-to-have)
      home.activation.ensureNpmGlobalDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${config.home.homeDirectory}/.local/npm"
      '';

    };
}
