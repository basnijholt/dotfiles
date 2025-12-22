# aliases.sh - meant to be sourced in .bash_profile/.zshrc

if [[ $- == *i* ]]; then
    alias cdw="cd ~/Work/ "
    alias cdc="cd ~/Code/ "
    alias mm="micromamba"
    alias p="pytest"
    alias py="python"
    alias pc="prek run --all-files"
    alias nv="nvim"
    alias ccat='command cat'
    alias last_conda_repodata_update='curl -sI https://conda.anaconda.org/conda-forge/linux-64/repodata.json | grep "last-modified"'  # Also see https://anaconda.statuspage.io/ and https://github.com/conda/infrastructure/issues/892
    alias gs='git status'  # I use `gst` from `oh-my-zsh` git plugin but this is a frequent typo
    fixssh() {
        if [[ -n "$ZELLIJ" ]]; then
            export SSH_AUTH_SOCK=$(ls -t ~/.ssh/agent/s.*.sshd.* 2>/dev/null | head -1)
        elif [[ -n "$TMUX" ]]; then
            eval $(tmux show-env -s | grep "^SSH_")  # https://stackoverflow.com/a/34683596
        else
            echo "Not in tmux or zellij"
        fi
    }
    alias gdom='git diff origin/main'
    alias grhom='git reset --hard origin/main'
    alias grsom='git reset --soft origin/main'
    alias gcai="${HOME}/dotfiles/scripts/commit.py --edit "
    alias gcaia="${HOME}/dotfiles/scripts/commit.py --edit --all "
    alias c='code'
    alias cl='claude --dangerously-skip-permissions '
    alias vcl='CLAUDE_CODE_USE_VERTEX=1 ANTHROPIC_MODEL="claude-opus-4-5" ANTHROPIC_SMALL_FAST_MODEL="claude-haiku-4-5" claude --dangerously-skip-permissions '
    alias co='coder --dangerously-bypass-approvals-and-sandbox '
    alias ge='gemini --yolo --model gemini-3-pro-preview'
    alias ze='zellij attach --create'
    alias killagent="pkill -9 -f '[a]gent-cli'"
    alias y='yazi '

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

    nixswitch() {
        local args=()
        if [[ -n "$1" ]]; then
            args=(--option max-jobs "$1" --option cores "$1")
        fi
        sudo nixos-rebuild switch --flake ~/dotfiles/configs/nixos#$(hostname) "${args[@]}"
    }
    
    nixupdate() {
        local args=()
        if [[ -n "$1" ]]; then
            args=(--option max-jobs "$1" --option cores "$1")
        fi
        cd ~/dotfiles/configs/nixos && nix flake update && sudo nixos-rebuild switch --flake .#$(hostname) "${args[@]}" && cd -
    }

    alias nixcacheupdate="~/dotfiles/configs/nixos/scripts/upgrade-from-cache.sh"

    zyolo() {
        export ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
        export ANTHROPIC_AUTH_TOKEN="$Z_API_KEY"
        claude --dangerously-skip-permissions "$@"
    }

    # Print to HP LaserJet M110we via hp print server
    hpprint() {
        if [[ -z "$1" ]]; then
            echo "Usage: hpprint <file> [copies]"
            echo "       echo 'text' | hpprint -"
            return 1
        fi
        local copies="${2:-1}"
        if [[ "$1" == "-" ]]; then
            lp -h hp.local:631 -d HP_LaserJet_M110we -n "$copies"
        else
            lp -h hp.local:631 -d HP_LaserJet_M110we -n "$copies" "$1"
        fi
    }

    wake() {
        local -A macs=(
            [nuc]="1C:69:7A:0C:B6:37"
            [hp]="C8:D9:D2:0C:E0:34"
            [truenas]="A8:B8:E0:04:49:DE"
            [pc]="24:4B:FE:48:60:2A"
        )
        local host="$1"
        if [[ -z "$host" ]]; then
            echo "Usage: wake <host>"
            echo "Available hosts: ${(k)macs}"
            return 1
        fi
        local mac="${macs[$host]}"
        if [[ -z "$mac" ]]; then
            echo "Unknown host: $host"
            echo "Available hosts: ${(k)macs}"
            return 1
        fi
        wakeonlan "$mac"
    }
fi
