from tree import print_with_comments, list_files

# Directory and file descriptions
descriptions = {
    # Git / code helpers
    "commit.py": "Generate a conventional commit message from staged changes",
    "git-fixup-file.sh": "Remove a file from commits since branching from main",

    # Backups / sync
    "rclone.sh": "Scheduled backups to Backblaze B2 (and rsync to the NAS)",
    "rsync-time-machine.sh": "Create incremental Time Machine-like backups using rsync",
    "sync-dotfiles.sh": "Push updater to hosts and trigger sync/install",
    "sync-local-dotfiles.sh": "On a host: pull latest and optionally run ./install",
    "sync-photos-to-nas.sh": "Sync photos to the NAS",
    "sync-uv.sh": "Globally install uv tools I frequently use",

    # Repo helpers
    "run.sh": "Run a command from .dotbins platform bin directory",
    "pypi-sha256.sh": "Print commands to update a conda-forge feedstock checksum",
}

if __name__ == "__main__":
    tree = list_files(folder="scripts", level=2)
    print("```bash")
    print_with_comments(tree, descriptions)
    print("```")
