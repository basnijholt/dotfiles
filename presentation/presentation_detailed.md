# My Dotfiles: A Deep Dive

This document provides a more detailed look into my dotfiles setup. It's a companion to the "Supercharge Your Terminal" presentation.

## Table of Contents

1.  [The "Why": Beyond the Basic Shell](#1-the-why-beyond-the-basic-shell)
2.  [What are "Dotfiles"?](#2-what-are-dotfiles)
3.  [My Dotfiles Philosophy](#3-my-dotfiles-philosophy)
4.  [A Tour of My Setup](#4-a-tour-of-my-setup)
    *   [The Core: The Shell](#the-core-the-shell)
    *   [Configuration Management](#configuration-management)
    *   [Application Configuration](#application-configuration)
    *   [Automation: Scripts](#automation-scripts)
    *   [Secrets Management](#secrets-management)
    *   [Cross-Platform Support with Nix](#cross-platform-support-with-nix)
5.  [How to Get Started](#5-how-to-get-started)

---

## 1. The "Why": Beyond the Basic Shell

Working on complex projects like quantum compilers requires a lot of time in the terminal. A basic, out-of-the-box shell is functional, but it's not optimized for the kind of work we do. By investing time in customizing our environment, we can reap huge rewards in productivity and comfort.

The goal is to create an environment that is:

*   **Efficient:** Reduce keystrokes, automate repetitive tasks, and surface relevant information when you need it.
*   **Consistent:** Have the same, familiar environment on your work machine, your personal laptop, and any remote servers you connect to.
*   **Personalized:** Your tools should work for you, not the other way around. Tailor your setup to your specific needs and preferences.
*   **Automated:** Let your computer handle the boring, repetitive tasks so you can focus on the interesting problems.

---

## 2. What are "Dotfiles"?

Dotfiles are configuration files for various programs on your system. They are called "dotfiles" because their filenames begin with a dot (`.`), which makes them hidden files on Unix-like operating systems. You can see them with `ls -a`.

Examples include:

*   `~/.zshrc`: Configuration for the Zsh shell.
*   `~/.bashrc`: Configuration for the Bash shell.
*   `~/.gitconfig`: Configuration for Git.
*   `~/.vimrc`: Configuration for the Vim editor.

By treating these files as code, we can version control them, share them across machines, and build a powerful, personalized development environment.

---

## 3. My Dotfiles Philosophy

*   **Automate Everything:** If you find yourself typing the same long command over and over, create an alias. If you have a multi-step process you do frequently, write a script. See the `scripts/` directory for examples.
*   **Manage with Code:** I use [Dotbot](https://github.com/anishathalye/dotbot) to manage my dotfiles. It reads a configuration file (`install.conf.yaml`) and creates symbolic links from this repository to the correct locations in my home directory. This makes installation on a new machine a breeze.
*   **Keep Secrets Secure:** My dotfiles are in a public repository, but my secrets are not. I use GPG to encrypt sensitive information and have scripts to `hide` and `reveal` them.
*   **Portability is Key:** I use tools and techniques that work on both macOS and Linux, the two operating systems I use most. This is achieved through a combination of shell scripting and [Nix](#cross-platform-support-with-nix).
*   **Modularity:** The `configs/` directory is organized by application, making it easy to find and update specific configurations. The shell configuration is broken down into multiple files in `configs/shell/` for better organization.
*   **Tooling is Code:** My dotfiles don't just manage configuration; they also manage the tools themselves. Using my custom tool, `dotbins`, I ensure that all essential CLI tools are version-controlled and available on any machine, just like the configs that use them.
*   **Pragmatism over Hype:** The setup prioritizes tools that are robust, stable, and work consistently across all my target environments (macOS, Linux). For example, I stick with `zsh` over `fish` for its POSIX compatibility on minimal systems, and I use iTerm2 for its mature, indispensable features, even when newer, faster terminals exist. The goal is a reliable, productive environment everywhere.

### A Note on Design Choices

This setup is the result of years of refinement, and some choices were made deliberately when compared to other popular tools:

*   **Why Not `fish`?** While `fish` is excellent, `zsh` provides a powerful, POSIX-compatible environment that works reliably on minimal Linux servers or HPC nodes where `bash` is the only other guarantee.
*   **Why iTerm2 on macOS?** I've tried many modern terminals (WezTerm, Kitty, Alacritty), but I always return to iTerm2. Its killer feature is **Semantic History**: the ability to `Cmd-Click` a file path with a line number (e.g., `src/my_module/file.py:123`) and have it open directly in my editor is non-negotiable for my workflow. Its configuration is also easily version-controlled as a JSON file.
*   **Why Dotbot over `chezmoi`?** `chezmoi` is powerful, but I prefer the directness of a standard Git repository. My setup relies heavily on **Git submodules** to manage plugins and tools, and Dotbot's simple symlinking and script execution model integrates perfectly with this submodule-centric workflow.

---

## 4. A Tour of My Setup

### The Core: The Shell

I use Zsh as my shell, enhanced with several tools:

*   **[Oh My Zsh](https://ohmyz.sh/):** A framework for managing Zsh configuration. It provides a lot of plugins and themes out of the box.
*   **[Starship](https://starship.rs/):** A minimal, fast, and highly customizable prompt. My configuration is in `configs/starship/starship.toml`. It shows useful information like the current Git branch, Python virtual environment, and more.
*   **Plugins & Tools:** I use several tools to enhance my shell experience, including:
    *   **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions):** Suggests commands as you type based on your history.
    *   **[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting):** Provides syntax highlighting for the command line.
    *   **[zoxide](https://github.com/ajeetdsouza/zoxide):** A smarter `cd` command. It remembers which directories you use most frequently, so you can "jump" to them in just a few keystrokes.
    *   **[Atuin](https://atuin.sh/):** Replaces the default shell history with a SQLite database, syncing it across all machines and providing a powerful, full-text search interface.
*   **My Zsh Configuration:**
    *   The main entry point is `configs/zsh/zshrc`.
    *   This sources `configs/shell/main.sh`, which in turn sources a series of modular shell scripts for aliases, exports, functions, etc.
    *   **Note on Evolution:** This setup is always evolving. For example, I have migrated from older script-based tools like `zsh-z` and `autoenv` to more modern, faster, and more powerful compiled tools like `zoxide` and `direnv`.

### Tooling Management with `dotbins`

A common problem with dotfiles is that they often contain configurations for tools that might not be installed on a new system. My aliases for `bat`, `fzf`, and `zoxide` are useless if those binaries are missing.

To solve this, I created **[`dotbins`](https://github.com/basnijholt/dotbins)**, a tool for managing CLI binaries directly within a dotfiles repository.

**How it works:**

1.  **Configuration:** A `dotbins.yaml` file defines a list of tools and their GitHub repositories. I manage many tools this way, including `bat`, `delta`, `eza`, `fzf`, `lazygit`, and `rg`.
2.  **Syncing:** Running `dotbins sync` downloads the correct pre-compiled binaries for each platform (macOS, Linux, Windows) and architecture I've configured.
3.  **No Admin Required:** It installs these binaries into a local directory (`~/.dotbins` by default), requiring no `sudo` or system-wide package manager.
4.  **Shell Integration:** It automatically generates shell scripts that add the correct binary directory to the `PATH` and can even inject tool-specific configurations (like `eval "$(zoxide init zsh)"`).
5.  **Git Submodule:** The `dotbins` binaries are stored in a separate Git repository, which I include as a submodule in my main dotfiles. This keeps my main repository clean while ensuring the tools are version-controlled and fetched when I clone my dotfiles.

This approach means that when I set up a new machine, I don't just get my configurations—I get all the essential command-line tools they depend on, ready to use instantly.

**The Payoff: Modernizing the Toolchain**

`dotbins` was the key that unlocked the ability to easily adopt a suite of modern, superior CLI tools.

| Old Tool            | New Way with `dotbins` | Advantage                                |
| ------------------- | ---------------------- | ---------------------------------------- |
| `zsh-z` (script)    | `zoxide` (binary)      | Faster, smarter, works across shells     |
| `cat`               | `bat`                  | Syntax highlighting, Git integration     |
| `ls`                | `eza`                  | Better formatting, icons, Git-aware      |
| `grep`              | `ripgrep`              | Much faster, respects `.gitignore`       |
| `ctrl+r` history    | `atuin`                | Synced, searchable history database      |
| standard `git diff` | `delta`                | Better visual diffs                      |

### Configuration Management

I use [Dotbot](https://github.com/anishathalye/dotbot) to manage the installation of my dotfiles. The configuration is in `install.conf.yaml`.

When I run the `install` script, Dotbot reads this file and performs the actions specified, such as:

*   Creating symbolic links from files in this repository to my home directory (e.g., `configs/zsh/zshrc` -> `~/.zshrc`).
*   Running shell commands to install packages or set up services.
*   Installing submodules.

This makes setting up a new machine as simple as cloning the repository and running one command.

### Application Configuration

I manage the configuration for many of the tools I use daily. You can find them in the `configs/` directory. Some notable examples include:

*   **`git`:** `configs/git/gitconfig` contains my main Git configuration, with personal and work-specific settings imported.
*   **`conda`/`mamba`:** `configs/conda/condarc` and `configs/mamba/mambarc` configure the package managers.
*   **`iterm2`:** `configs/iterm/Profiles.json` contains my iTerm2 terminal profiles. The killer feature for me is its robust **Semantic History**, allowing me to `Cmd-Click` file paths and URLs to open them directly in the correct application (e.g., VS Code at the exact line number).
*   **`karabiner`:** `configs/karabiner/karabiner.json` for advanced keyboard remapping on macOS.
*   **[Keyboard Maestro](https://www.keyboardmaestro.com/):** While not a traditional dotfile, I include my Keyboard Maestro macros (`configs/keyboard-maestro/`) for automating complex, system-wide workflows with keyboard shortcuts.
*   **[direnv](https://direnv.net/):** `configs/direnv/direnvrc` is used to load and unload environment variables depending on the current directory. This is incredibly useful for managing project-specific secrets and settings, especially for Python projects using `uv` or `micromamba`.
*   **[keychain](https://www.funtoo.org/Funtoo:Keychain):** I use keychain to manage SSH and GPG keys, so I only have to enter my passphrase once per session. It's a huge time-saver.

### Automation: Scripts

The `scripts/` directory is full of useful scripts to automate various tasks. Some examples:

*   `scripts/sync-dotfiles.sh`: Syncs the dotfiles with the remote repository.
*   `scripts/commit.py`: A helper script for making commits.
*   `scripts/transcribe.py`: A script to transcribe audio files.

### Secrets Management

I keep my dotfiles in a public repository on GitHub, so I need a way to manage secrets like API keys, passwords, and SSH keys.

*   I have a `secrets/` directory which is a private Git repository.
*   I use GPG to encrypt sensitive files.
*   The `secrets/hide` and `secrets/reveal` scripts make it easy to encrypt and decrypt secrets.
*   The `secrets` directory is included in the main dotfiles repository as a submodule.

### Cross-Platform Support with Nix

To ensure a consistent environment across my macOS and Linux machines, I use [Nix](https://nixos.org/).

*   **Nix:** A powerful package manager and system configuration tool. It allows you to declare the desired state of your system in a configuration file.
*   **`nix-darwin`:** For macOS, I use `nix-darwin` to manage my system configuration. The configuration is in `configs/nix-darwin/configuration.nix`.
*   **`nixos`:** For Linux, I use `nixos`. The configuration is in `configs/nixos/configuration.nix`.
*   **Flakes:** I use Nix Flakes to manage dependencies and ensure reproducible builds. See `flake.nix`.

This approach allows me to define my entire system configuration as code, which is version controlled and easily reproducible.

---

## 5. How to Get Started

1.  **Start Small:** You don't need to build a complex system like this all at once. Start by editing your `.bashrc` or `.zshrc` file. Add a few aliases for commands you use often.
2.  **Use a Framework:** A framework like [Oh My Zsh](https://ohmyz.sh/) can give you a lot of features out of the box.
3.  **Version Control:** Create a new repository on GitHub (or another Git provider) for your dotfiles.
4.  **Use a Dotfile Manager:** A tool like [Dotbot](https://github.com/anishathalye/dotbot) or [Stow](https://www.gnu.org/software/stow/) will make managing your dotfiles much easier.
5.  **Fork, Don't Just Clone!** Start by forking a repository that you like. This gives you a solid foundation that you can then tweak and customize to fit your own needs. Don't use my `gitconfig` directly!
6.  **Steal (and Share)!** The best way to learn is to look at what others have done. You can find many examples of dotfiles repositories on GitHub. Feel free to take inspiration from my setup.

My dotfiles are available at [Your Git Repo Link].
