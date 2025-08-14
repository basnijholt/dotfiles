# aliases.sh - meant to be sourced in .bash_profile/.zshrc

if [[ $- == *i* ]]; then
    alias cdw="cd ~/Work/ "
    alias cdc="cd ~/Code/ "
    alias mm="micromamba"
    alias p="pytest"
    alias py="python"
    alias pc="pre-commit run --all-files"
    alias ccat='command cat'
    alias last_conda_repodata_update='curl -sI https://conda.anaconda.org/conda-forge/linux-64/repodata.json | grep "last-modified"'  # Also see https://anaconda.statuspage.io/ and https://github.com/conda/infrastructure/issues/892
    alias gs='git status'  # I use `gst` from `oh-my-zsh` git plugin but this is a frequent typo
    alias fixssh='eval $(tmux show-env -s |grep "^SSH_")'  # https://stackoverflow.com/a/34683596
    alias gcai="${HOME}/dotfiles/scripts/commit.py --edit "
    alias gcaia="${HOME}/dotfiles/scripts/commit.py --edit --all "
    alias c='code'
    alias ze='zellij attach --create'

    if [[ `uname` == 'Darwin' ]]; then
        alias j='jupyter notebook'
        alias ci='code-insiders'
        alias s='/usr/local/bin/subl'
        alias ss='open -b com.apple.ScreenSaver.Engine'
        alias tun='autossh -N -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -L 8888:localhost:9999 cw'
        alias nixswitch="darwin-rebuild switch --flake ~/dotfiles/configs/nix-darwin"

        # Relies on having installed x86 brew like:
        # arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
        alias x86brew="arch -x86_64 /usr/local/bin/brew"
        alias brew="/opt/homebrew/bin/brew"  # M1 version, to avoid from using x86 version accidentally
    fi
    if [[ `uname` == 'Linux' ]]; then
        alias pbcopy='wl-copy'  # Just because of muscle memory...
    fi

    if [[ `hostname` == 'nixos' ]]; then
        alias nixswitch='sudo cp ~/dotfiles/configs/nixos/*.nix /etc/nixos/; sudo nixos-rebuild switch --flake /etc/nixos#nixos --upgrade-all; cp /etc/nixos/flake.lock ~/dotfiles/configs/nixos/'
    fi
fi
