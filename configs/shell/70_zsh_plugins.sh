# zsh_plugins.sh - meant to be sourced in .zshrc

if [[ ($- == *i*) && -n "$ZSH_VERSION" ]]; then
    # -- oh-my-zsh
    [[ -z $STARSHIP_SHELL ]] && export ZSH_THEME="mytheme"
    DEFAULT_USER="basnijholt"
    export DISABLE_AUTO_UPDATE=true  # Speedup of 40%
    plugins=( git sudo iterm2 uv docker-compose )
    command -v eza >/dev/null && zstyle ':omz:lib:directories' aliases no  # Skip aliases in directories.zsh if eza
    export ZSH=~/dotfiles/submodules/oh-my-zsh
    source $ZSH/oh-my-zsh.sh

    # -- zsh plugins
    source ~/dotfiles/submodules/zsh-autosuggestions/zsh-autosuggestions.zsh
    source ~/dotfiles/submodules/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

    # -- fix Atuin [Ctrl-r] key binding
    if command -v atuin &> /dev/null; then
        bindkey -M emacs '^r' atuin-search  # Rebind after omz/lib/key-bindings.zsh
    fi

    # -- if on Linux
    if [[ "$(uname -s)" == "Linux" ]]; then
        # Provides ctrl+backspace and ctrl+delete
        # Note: in kinto.nix I remap these to Alt+Backspace and Alt+Delete
        bindkey '^H' backward-kill-word
        bindkey '^[[3;5~' kill-word
    fi

    # -- Custom keybindings (Alt/Option key combinations)
    # Based on oh-my-zsh dirhistory plugin escape sequences
    function _cd_up() { zle .kill-buffer; cd ..; zle .accept-line }
    function _cd_back() { zle .kill-buffer; cd - >/dev/null; zle .accept-line }
    zle -N _cd_up
    zle -N _cd_back

    # Option+Left/Right: word navigation (both terminals now send ESC b / ESC f)
    bindkey '^[b' backward-word
    bindkey '^[f' forward-word

    case "$TERM_PROGRAM" in
    Apple_Terminal)
        bindkey '^[^?' backward-kill-word
        bindkey '^[^[OA' _cd_up           # Option+Up (cd ..)
        bindkey '^[^[OB' _cd_back         # Option+Down (cd -)
        ;;
    iTerm.app)
        bindkey '^[[1;3A' _cd_up          # Option+Up (cd ..)
        bindkey '^[[1;3B' _cd_back        # Option+Down (cd -)
        # Alt+Backspace handled in iTerm profile (sends Ctrl+W)
        ;;
    esac

fi
