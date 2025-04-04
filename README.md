# 🏠 basnijholt's dotfiles

A carefully designed cross-platform dotfiles configuration that powers my development environments across macOS and Linux systems.
This repository represents years of refinement to create a consistent, modular, and reliable setup.

I run this configuration on at least 10 machines, including `arm64` *macOS*, `x86_64` and `aarm64` versions of *Ubuntu*, *Debian*, *DietPi*, *Raspberry Pi OS*, and even on my *iPhone* via iSH which emulates `i386` Linux.

My main goal is to have consistency and a super smooth bootstrapping experience for new machines, and to have a consistent setup across all my devices.

> [!TIP]
> I have written several blog posts about my shell setup and the tools I use.
> See [Be a Ninja in the Terminal 🥷](https://www.nijho.lt/post/terminal-ninja/), [dotbins: Managing Binary Tools in Your Dotfiles 🧰](https://www.nijho.lt/post/dotbins/), and [Combining Keychain and 1Password CLI for SSH Agent Management 🔑](https://www.nijho.lt/post/ssh-1password-funtoo-keychain/) for more details.

> [!NOTE]
> I have maintained this repository since 2019-04 but started a new commit history when I made it public in 2025-04.

## ✨ Features

- **Shell agnostic** - Works with both `zsh` and `bash`
- **Cross-platform** - Supports macOS and Linux
- **Modular design** - Organized in independent, composable configuration files
- **Easy installation** - Uses [dotbot](https://github.com/anishathalye/dotbot) for automated symlink management
- **Binary management** - Uses [dotbins](https://github.com/basnijholt/dotbins) for CLI tools with automatic shell integration
- **Remote syncing** - Includes scripts to sync dotfiles across machines
- **nix-darwin integration** - Uses Nix for declarative macOS configuration
- **Isolated environments** - Supports direnv, micromamba, and other environment managers

## 🚀 Quick Start

### Prerequisites

First, you need to set up SSH authentication to access private submodules.

<details>
<summary><b>Using 1Password</b></summary>

Install 1Password and set up the SSH agent:

```bash
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

</details>

### Installation

```bash
# Clone the repository with submodules
git clone --recurse-submodules -j8 git@github.com:basnijholt/dotfiles.git
cd dotfiles

# Run the installation script
./install
```

### Update Remote Machines

```bash
# Sync dotfiles to all configured remote hosts
./scripts/sync-dotfiles.sh

# Or install new configuration on remotes
./scripts/sync-dotfiles.sh install
```

## 🧩 Repository Structure

<!-- CODE:BASH:START -->
<!-- python3 .github/scripts/repo_structure.py -->
<!-- CODE:END -->

<!-- OUTPUT:START -->
<!-- ⚠️ This content is auto-generated by `markdown-code-runner`. -->
```bash
.
├── README.md
├── configs                          # Configuration files for various tools
│   ├── atuin                        # Shell history management
│   ├── bash                         # Bash-specific configuration
│   ├── conda                        # Conda/Mamba configuration
│   ├── dask                         # Dask distributed computing
│   ├── direnv                       # Directory-specific environment setup
│   ├── git                          # Git configuration
│   ├── iterm                        # iTerm2 profiles
│   ├── karabiner                    # Keyboard customization for macOS
│   ├── keyboard-maestro             # Keyboard Maestro macros and configurations
│   ├── mamba                        # Mamba package manager settings
│   ├── nix-darwin                   # Nix configuration for macOS
│   ├── shell                        # Shell-agnostic configurations
│   ├── starship                     # Cross-shell prompt
│   ├── syncthing                    # File synchronization
│   └── zsh                          # Zsh-specific configuration
├── install                          # Installation script
├── install.conf.yaml                # Dotbot configuration
├── submodules                       # Git submodules for external tools
│   ├── autoenv
│   ├── dotbins                      # Binaries manager in dotfiles
│   ├── dotbot                       # Dotfiles installation
│   ├── keychain                     # SSH key management
│   ├── mydotbins                    # CLI tool binaries managed by dotbins
│   ├── oh-my-zsh                    # Zsh framework
│   ├── rsync-time-backup
│   ├── syncthing-resolve-conflicts  # File synchronization
│   ├── tmux                         # oh-my-tmux configuration
│   ├── truenas-zfs-unlock
│   ├── zsh-autosuggestions          # Zsh-specific configuration
│   ├── zsh-fzf-history-search       # Zsh-specific configuration
│   ├── zsh-syntax-highlighting      # Zsh-specific configuration
│   └── zsh-z                        # Zsh-specific configuration
└── uninstall.py                     # Uninstallation script
```

<!-- OUTPUT:END -->

## 📋 Shell Configuration

The shell configuration is structured in a modular way under `configs/shell/`. The main entry point is `main.sh` which sources other shell-specific files in a specific order:

<!-- CODE:BASH:START -->
<!-- python3 .github/scripts/shell_files.py -->
<!-- CODE:END -->

<!-- OUTPUT:START -->
<!-- ⚠️ This content is auto-generated by `markdown-code-runner`. -->
```bash
configs/shell
├── 00_prefer_zsh.sh       # ZSH auto-switching
├── 05_zsh_completions.sh  # ZSH completions setup
├── 10_aliases.sh          # Shell aliases
├── 20_exports.sh          # Environment variables
├── 30_misc.sh             # Miscellaneous settings
├── 40_keychain.sh         # SSH key management
├── 50_python.sh           # Python environment setup
├── 60_slurm.sh            # HPC cluster integration
├── 70_zsh_plugins.sh      # ZSH plugins setup
└── main.sh                # Main shell configuration file
```

<!-- OUTPUT:END -->

This modular approach makes it easy to understand, maintain, and customize each aspect of the shell environment.

This setup allows my `.zshrc` to be as simple as:

<!-- CODE:BASH:START -->
<!-- echo '```bash' -->
<!-- cat configs/zsh/zshrc -->
<!-- echo '```' -->
<!-- CODE:END -->

<!-- OUTPUT:START -->
<!-- ⚠️ This content is auto-generated by `markdown-code-runner`. -->
```bash
# zmodload zsh/zprof # Uncomment for profiling

source ~/dotfiles/configs/shell/main.sh

# zprof # Uncomment for profiling
```

<!-- OUTPUT:END -->

and `.bash_profile` to be:

<!-- CODE:BASH:START -->
<!-- echo '```bash' -->
<!-- cat configs/bash/bash_profile -->
<!-- echo '```' -->
<!-- CODE:END -->

<!-- OUTPUT:START -->
<!-- ⚠️ This content is auto-generated by `markdown-code-runner`. -->
```bash
source ~/dotfiles/configs/shell/main.sh
```

<!-- OUTPUT:END -->

## 🔧 Key Components

### Shell Integration

- **Zsh** - Primary shell with Oh-My-Zsh, custom theme, and plugins
- **Bash** - Fallback shell with compatible configuration
- **Automatic shell detection** - Switches to Zsh automatically if available

### Development Tools

- **Git** - Comprehensive Git configuration with signing, aliases, and more
- **Python** - Support for conda/mamba/micromamba environments
- **Direnv** - Directory-specific environment variables
- **SSH** - Key management with keychain integration

### macOS Enhancements

- **nix-darwin** - Declarative system configuration
- **Homebrew** - Package management via Nix
- **Karabiner** - Keyboard customization
- **iTerm2** - Terminal customization

### Utility Scripts

The repository includes several useful utility scripts:

<!-- CODE:BASH:START -->
<!-- python3 .github/scripts/utility_scripts.py -->
<!-- CODE:END -->

<!-- OUTPUT:START -->
<!-- ⚠️ This content is auto-generated by `markdown-code-runner`. -->
```bash
scripts
├── eqMac.py
├── eqMac.sh                   # Poor man's Supervisord/Launchd/Systemd for eqMac because it keeps crashing
├── nbviewer.sh                # Script to share Jupyter notebooks via nbviewer
├── pypi-sha256.sh             # Generate the commands to update a conda-forge feedstock
├── rclone.sh                  # Scheduled backups to B2 cloud storage
├── rpi
├── rsync-time-machine.sh      # Create incremental Time Machine-like backups using rsync
├── signature.html
├── sync-dotfiles.sh           # Sync dotfiles to remote machines
├── sync-local-dotfiles.sh     # Update dotfiles on the local machine
├── sync-photos-to-truenas.sh  # Sync photos to TrueNAS server
└── upload-file.sh             # Share files via various file hosting services
```

<!-- OUTPUT:END -->

## 🔨 dotbins Integration

This repository uses [dotbins](https://github.com/basnijholt/dotbins) to manage CLI tools across platforms. The `dotbins.yaml` configuration defines both the tools to install and their shell integration:

```yaml
tools_dir: ~/.dotbins

tools:
  # Simple tools that need no special configuration
  delta: dandavison/delta
  fd: sharkdp/fd
  rg: BurntSushi/ripgrep

  # Tools with custom shell integration
  bat:
    repo: sharkdp/bat
    shell_code:
      zsh: |
        alias bat="bat --paging=never"
        alias cat="bat --plain --paging=never"
  fzf:
    repo: junegunn/fzf
    shell_code:
      zsh: |
        source <(fzf --zsh)
  # ...and more
```

dotbins automatically:

1. Downloads binaries for your platform
2. Organizes them by OS and architecture
3. Creates shell integration scripts with your custom aliases and initialization code
4. Updates all tools with a single command

The generated shell script at `~/.dotbins/shell/zsh.sh` is sourced in your shell configuration, making all tools immediately available with their proper setup.

## 🖥️ Platform-Specific Features

### macOS

Before running Nix-darwin, set the hostname:

```bash
NAME="basnijholt-macbook-pro"
sudo scutil --set HostName $NAME
sudo scutil --set LocalHostName $NAME
sudo scutil --set ComputerName $NAME
dscacheutil -flushcache
```

The repository includes nix-darwin configuration for a reproducible macOS setup:

```bash
# Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Apply nix-darwin configuration
nixswitch  # Alias for darwin-rebuild switch --flake ~/dotfiles/configs/nix-darwin
```

#### Homebrew packages

The nix-darwin configuration manages Homebrew packages declaratively.
See the [`configs/nix-darwin/homebrew.nix`](`configs/nix-darwin/homebrew.nix`) file for the list of packages.

### Linux

For Linux systems, the configuration automatically adapts to the available environment and provides compatibility with various distributions.

## 🔄 Syncing to Remote Machines

The repository includes scripts to easily sync your dotfiles to remote machines:

```bash
# Sync to all configured remote hosts
./scripts/sync-dotfiles.sh

# Install configuration on remotes (re-run dotbot)
./scripts/sync-dotfiles.sh install
```

## 🔐 Secrets Management

Sensitive information is stored in a separate private repository with additional encryption using GPG and [git-secret](https://github.com/sobolevn/git-secret). The structure is as follows:

```
secrets/             # Private git submodule
└── install          # Installation script for secrets
```

This submodule requires SSH authentication to access, which is why setting up SSH keys as described in the prerequisites is essential.

## 🔍 Customization

To customize these dotfiles for your own use:

1. Fork this repository
2. Update Git configurations with your information in `configs/git/`
3. Modify shell configurations in `configs/shell/`
4. Adjust the `install.conf.yaml` to match your needs
5. Update the dotbins.yaml configuration with your preferred tools
6. Remove or modify platform-specific configurations as necessary

## 📚 Additional Resources

- [dotbot documentation](https://github.com/anishathalye/dotbot)
- [dotbins documentation](https://github.com/basnijholt/dotbins)
- [nix-darwin documentation](https://github.com/nix-darwin/nix-darwin)

## 📄 License

This project is open-source and available under the MIT License.
