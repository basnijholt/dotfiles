# main.sh - can be sourced in .bash_profile/.bashrc or .zshrc

[ -n "$BASH_VERSION" ] && source ~/dotfiles/configs/shell/00_prefer_zsh.sh  # no-op in zsh
[ -n "$ZSH_VERSION" ] && source ~/dotfiles/configs/shell/05_zsh_completions.sh
source ~/dotfiles/configs/shell/10_aliases.sh
source ~/dotfiles/configs/shell/20_exports.sh
source ~/dotfiles/configs/shell/30_misc.sh
source ~/dotfiles/configs/shell/40_keychain.sh
source ~/dotfiles/configs/shell/50_python.sh
source ~/dotfiles/configs/shell/60_slurm.sh
[ -n "$ZSH_VERSION" ] && source ~/dotfiles/configs/shell/70_zsh_plugins.sh
