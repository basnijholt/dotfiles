from tree import print_with_comments, list_files

# Directory and file descriptions
descriptions = {
    # Maintenance / system
    "apt-update.sh": "Debian/Ubuntu update: apt update/upgrade/autoremove/autoclean",
    "setup-atuin-daemon.sh": "Setup Atuin as a user systemd service",

    # Git / code helpers
    "commit.py": "Generate a conventional commit message from staged changes",
    "git-fixup-file.sh": "Remove a file from commits since branching from main",

    # Notebooks and uploads
    "nbviewer.sh": "Share a Jupyter notebook via nbviewer (after upload)",
    "upload-file.sh": "Upload files to various paste/file hosts",

    # Backups / sync
    "rclone.sh": "Scheduled backups to Backblaze B2 (and rsync to TrueNAS)",
    "rsync-time-machine.sh": "Create incremental Time Machine-like backups using rsync",
    "sync-dotfiles.sh": "Push updater to hosts and trigger sync/install",
    "sync-local-dotfiles.sh": "On a host: pull latest and optionally run ./install",
    "sync-photos-to-truenas.sh": "Sync photos to TrueNAS server",
    "sync-uv-tools.sh": "Globally install uv tools I frequently use",

    # AI / LLM utilities
    "fix_my_text_ollama.py": "Clipboard text grammar fix using a local Ollama model",
    "transcribe.py": "Stream mic audio to a Wyoming ASR server (clipboard optional)",
    "voice_clipboard_assistant.py": "Voice command assistant for clipboard text via Ollama",

    # Repo helpers
    "post-clone.sh": "Initialize submodules with LFS skip for mydotbins, then init rest",
    "remove-box.py": "Strip box-drawing characters from copied code snippets",
    "run.sh": "Run a command from .dotbins platform bin directory",
    "pypi-sha256.sh": "Print commands to update a conda-forge feedstock checksum",
}

if __name__ == "__main__":
    tree = list_files(folder="scripts", level=2)
    print("```bash")
    print_with_comments(tree, descriptions)
    print("```")
