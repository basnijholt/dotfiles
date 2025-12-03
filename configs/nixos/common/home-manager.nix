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
        # Check for dotbot submodule to detect incomplete clones
        if [ ! -d "${config.home.homeDirectory}/dotfiles/submodules/dotbot" ]; then
          # Remove incomplete clone if it exists
          run rm -rf "${config.home.homeDirectory}/dotfiles"
          # Ensure git and git-lfs are in PATH
          export PATH="${pkgs.git}/bin:${pkgs.git-lfs}/bin:$PATH"
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
          # Pull LFS files in main repo (submodule LFS can be fetched manually if needed)
          run cd "${config.home.homeDirectory}/dotfiles" && ${pkgs.git-lfs}/bin/git-lfs pull
          # Pull LFS in submodules - pass PATH to the subshell
          run cd "${config.home.homeDirectory}/dotfiles" && ${pkgs.git}/bin/git submodule foreach --recursive "PATH=${pkgs.git}/bin:${pkgs.git-lfs}/bin:\$PATH ${pkgs.git-lfs}/bin/git-lfs pull || true"
        fi
      '';

      # Run dotbot to symlink dotfiles
      home.activation.runDotbot = lib.hm.dag.entryAfter [ "cloneDotfiles" ] ''
        if [ -d "${config.home.homeDirectory}/dotfiles/submodules/dotbot" ]; then
          # Ensure python3 and zsh are in PATH for dotbot
          export PATH="${pkgs.python3}/bin:${pkgs.zsh}/bin:${pkgs.git}/bin:$PATH"
          run ${config.home.homeDirectory}/dotfiles/install || true
        else
          echo "Skipping dotbot: dotfiles not fully cloned"
        fi
      '';

    };
}
