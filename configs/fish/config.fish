# config.fish - Fish shell configuration
# Equivalent to zsh setup in ~/dotfiles/configs/shell/

# =============================================================================
# Exports (from 20_exports.sh)
# =============================================================================
set -gx LC_ALL en_US.UTF-8
set -gx LANG en_US.UTF-8
set -gx EDITOR nano
set -gx TMPDIR /tmp
set -gx UPLOAD_FILE_TO transfer.sh
set -gx MY_OLLAMA_HOST http://pc.local:11434
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx OLLAMA_KEEP_ALIVE 1h
set -gx LESS -R

fish_add_path "$HOME/.local/bin"
fish_add_path "$HOME/.local/npm/bin"
fish_add_path "/nix/var/nix/profiles/default/bin"

# =============================================================================
# Homebrew (macOS only)
# =============================================================================
if test -f /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
end

# =============================================================================
# Rust
# =============================================================================
if test -d "$HOME/.cargo/bin"
    fish_add_path "$HOME/.cargo/bin"
end

# =============================================================================
# Tool initializations (managed by dotbins)
# =============================================================================
if test -f "$HOME/.dotbins/shell/fish.fish"
    source "$HOME/.dotbins/shell/fish.fish"
end

# =============================================================================
# Micromamba / Conda (from 50_python.sh)
# =============================================================================
if command -v micromamba >/dev/null 2>&1
    set -gx MAMBA_EXE (command -v micromamba)
    set -gx MAMBA_ROOT_PREFIX "$HOME/micromamba"
    micromamba shell hook --shell fish | source
end

# Pixi
if test -f "$HOME/.pixi/bin/pixi"
    fish_add_path "$HOME/.pixi/bin"
    pixi completion --shell fish | source
end

# =============================================================================
# Aliases (from 10_aliases.sh)
# =============================================================================

# Tool aliases
alias bat="bat --paging=never"
alias cat="bat --plain --paging=never"
alias l="eza --long --all --git --icons=auto"
alias lg=lazygit
alias mm=micromamba

# Directory shortcuts
alias cdw="cd ~/Work/"
alias cdc="cd ~/Code/"

# Development
alias p=pytest
alias py=python
alias pc="pre-commit run --all-files"
alias nv=nvim
alias ccat="command cat"
alias gs="git status"

# AI tools
alias c=code
alias cl="claude --dangerously-skip-permissions"
alias vcl="CLAUDE_CODE_USE_VERTEX=1 ANTHROPIC_MODEL=claude-opus-4-5 ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5 claude --dangerously-skip-permissions"
alias co="coder --dangerously-bypass-approvals-and-sandbox"
alias ge="gemini --yolo --model gemini-3-pro-preview"
alias y=yazi

# Utilities
alias ze="zellij attach --create"
alias killagent="pkill -9 -f '[a]gent-cli'"

# macOS specific
if test (uname) = Darwin
    alias j="jupyter notebook"
    alias ci=code-insiders
    alias ss="open -b com.apple.ScreenSaver.Engine"
    alias nixswitch="darwin-rebuild switch --flake ~/dotfiles/configs/nix-darwin"
    alias x86brew="arch -x86_64 /usr/local/bin/brew"
    alias brew="/opt/homebrew/bin/brew"
end

# Linux specific
if test (uname) = Linux
    alias pbcopy=wl-copy
end

# =============================================================================
# Functions (from 10_aliases.sh)
# =============================================================================

function fixssh --description "Fix SSH agent in tmux"
    eval (tmux show-env -s | grep "^SSH_")
end

function zyolo --description "Use Z.ai API with Claude"
    set -gx ANTHROPIC_BASE_URL https://api.z.ai/api/anthropic
    set -gx ANTHROPIC_AUTH_TOKEN "$Z_API_KEY"
    claude --dangerously-skip-permissions $argv
end

# =============================================================================
# SSH Agent (macOS uses launchd, Linux would use keychain)
# =============================================================================
if test (uname) = Darwin
    if test -f ~/.ssh/id_ed25519
        set -gx SSH_AUTH_SOCK (launchctl getenv SSH_AUTH_SOCK)
        ssh-add -l >/dev/null 2>&1; or ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null
    end
end

# =============================================================================
# LM Studio CLI
# =============================================================================
if test -f "$HOME/.lmstudio/bin/lms"
    fish_add_path "$HOME/.lmstudio/bin"
end

# =============================================================================
# Secrets (non-public parts)
# =============================================================================
if test -f "$HOME/dotfiles/secrets/configs/fish/config.fish"
    source "$HOME/dotfiles/secrets/configs/fish/config.fish"
end
