# Home Manager configuration
{ lib, pkgs, ... }:

{
  home-manager.users.basnijholt =
    { config, lib, pkgs, ... }:
    {
      home.stateVersion = "25.05";

      home.activation.ensureNpmGlobalDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${config.home.homeDirectory}/.local/npm"
      '';

      # Clone dotfiles and run dotbot on first nixos-rebuild
      home.activation.setupDotfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${pkgs.git}/bin:${pkgs.git-lfs}/bin:${pkgs.python3}/bin:$PATH"
        if [ ! -d "${config.home.homeDirectory}/dotfiles/.git" ]; then
          run ${pkgs.git-lfs}/bin/git-lfs install
          export GIT_LFS_SKIP_SMUDGE=1
          run ${pkgs.git}/bin/git -c url."https://github.com/".insteadOf="git@github.com:" \
            clone --depth 1 https://github.com/basnijholt/dotfiles.git "${config.home.homeDirectory}/dotfiles"
          unset GIT_LFS_SKIP_SMUDGE
          run cd "${config.home.homeDirectory}/dotfiles" && ${pkgs.git-lfs}/bin/git-lfs pull
          run cd "${config.home.homeDirectory}/dotfiles" && ${pkgs.git}/bin/git \
            -c url."https://github.com/".insteadOf="git@github.com:" \
            submodule update --init --recursive --depth 1 --jobs=8 -- ':!secrets'
        fi
        run ${config.home.homeDirectory}/dotfiles/install || true
      '';
    };
}
