from tree import print_with_comments, list_files

# Directory and file descriptions
descriptions = {
    # Top-level
    "configs": "Configuration files for various tools",
    "Dockerfile": "Docker container that runs this dotfiles configuration",
    "README.md": "You are here",
    "install.conf.yaml": "Dotbot configuration",
    "install": "Installation script",
    "uninstall.py": "Uninstallation script",

    # configs/*
    "agent-cli": "Agent CLI configuration",
    "amp": "Amp Code settings",
    "atuin": "Shell history management",
    "bash": "Bash-specific configuration",
    "bat": "bat pager configuration",
    "claude": "Claude Code settings",
    "codex": "Codex CLI configuration",
    "conda": "Conda/Mamba configuration",
    "dask": "Dask distributed computing",
    "direnv": "Directory-specific environment setup",
    "gemini": "Gemini settings",
    "git": "Git configuration",
    "hypr": "Hyprland window manager config",
    "hyprpanel": "Hyprpanel configuration",
    "iterm": "iTerm2 profiles",
    "karabiner": "Keyboard customization for macOS",
    "keyboard-maestro": "Keyboard Maestro macros and configurations",
    "lazygit": "lazygit configuration",
    "mako": "Wayland notifications (mako)",
    "mamba": "Mamba package manager settings",
    "nix-darwin": "Nix configuration for macOS",
    "nixos": "NixOS system configurations",
    "shell": "Shell-agnostic configurations",
    "starship": "Cross-shell prompt",
    "syncthing": "File synchronization",
    "wezterm": "WezTerm terminal configuration",
    "zellij": "Zellij terminal multiplexer config",
    "zsh": "Zsh-specific configuration",

    # submodules/*
    "submodules": "Git submodules for external tools",
    "autoenv": "Directory-based environments",
    "dotbot": "Dotfiles installation",
    "dotbins": "Binaries manager in dotfiles",
    "mechabar": "Waybar + Rofi theme (Hyprland)",
    "mydotbins": "CLI tool binaries managed by dotbins",
    "oh-my-zsh": "Zsh framework",
    "rsync-time-backup": "Time-Machine style backup with rsync",
    "syncthing-resolve-conflicts": "Syncthing conflicts helper",
    "tmux": "oh-my-tmux configuration",
    "truenas-zfs-unlock": "Unlock ZFS pools on TrueNAS",
    "zsh-autosuggestions": "Zsh autosuggestions plugin",
    "zsh-fzf-history-search": "Fuzzy history search",
    "zsh-syntax-highlighting": "Zsh syntax highlighting",
    "zsh-z": "Frecent directory jumper",
}


if __name__ == "__main__":
    tree = list_files(folder=".", excludes=["^secrets$", "^scripts/.+$", r"^\..+$"])
    print("```bash")
    print_with_comments(tree, descriptions)
    print("```")
