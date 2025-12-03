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

      # Clone dotfiles repo if not present (uses HTTPS to avoid SSH key requirement)
      home.activation.cloneDotfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -d "${config.home.homeDirectory}/dotfiles" ]; then
          # Ensure git is in PATH (git-lfs needs it)
          export PATH="${pkgs.git}/bin:$PATH"
          # Initialize LFS hooks
          run ${pkgs.git-lfs}/bin/git-lfs install
          # Clone without LFS files and without submodules first
          export GIT_LFS_SKIP_SMUDGE=1
          run ${pkgs.git}/bin/git \
            -c url."https://github.com/".insteadOf="git@github.com:" \
            clone \
            --depth 1 \
            https://github.com/basnijholt/dotfiles.git \
            "${config.home.homeDirectory}/dotfiles"
          # Init submodules excluding 'secrets' (private repo, needs SSH key)
          run cd "${config.home.homeDirectory}/dotfiles" && ${pkgs.git}/bin/git \
            -c url."https://github.com/".insteadOf="git@github.com:" \
            submodule update --init --recursive --depth 1 --jobs=8 -- ':!secrets'
          # Pull LFS files (in main repo and all submodules)
          run cd "${config.home.homeDirectory}/dotfiles" && ${pkgs.git-lfs}/bin/git-lfs pull
          run cd "${config.home.homeDirectory}/dotfiles" && ${pkgs.git}/bin/git submodule foreach --recursive ${pkgs.git-lfs}/bin/git-lfs pull
        fi
      '';

      # Run dotbot to symlink dotfiles
      home.activation.runDotbot = lib.hm.dag.entryAfter [ "cloneDotfiles" ] ''
        run ${config.home.homeDirectory}/dotfiles/install
      '';

    };
}
