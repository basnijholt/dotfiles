#!/usr/bin/env python3
"""Minimal public-branch sync.

Steps:
 1) Checkout/reset PUBLIC_BRANCH from origin/BASE_BRANCH
 2) Remove exact paths listed in .publicignore (no globs)
 3) Replace configs/git/gitconfig-personal with example
 4) Convert submodule SSH URLs to HTTPS for public access
 5) Commit sanitized content (first commit - has HTTPS URLs)
 6) Pin bootstrap.sh to first commit's SHA (second commit)
 7) Force-push PUBLIC_BRANCH (auto in CI; locally with PUSH=1)
"""

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def log(msg: str) -> None:
    print(f"[sync-public] {msg}")


def run(args, *, check=True, capture=False):
    return subprocess.run(
        args,
        check=check,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )


def main() -> int:
    repo_root = Path(
        run(["git", "rev-parse", "--show-toplevel"], capture=True).stdout.strip()
    )
    os.chdir(repo_root)

    base = os.getenv("BASE_BRANCH", "main")
    public = os.getenv("PUBLIC_BRANCH", "public")

    # Make sure we have the latest origin state
    run(["git", "fetch", "--prune", "origin"], check=False)
    short_sha = run(
        ["git", "rev-parse", "--short", f"origin/{base}"], capture=True
    ).stdout.strip()

    log(f"Base branch:    {base}")
    log(f"Public branch: {public}")
    log(f"Repo root:       {repo_root}")
    log(f"Checking out {public} from origin/{base} ({short_sha})")

    run(["git", "checkout", "-B", public, f"origin/{base}"])
    run(["git", "reset", "--hard", f"origin/{base}"])

    # 1) Remove listed items
    log("Applying removals from .publicignore")
    ignore_file = repo_root / ".publicignore"
    for raw in ignore_file.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        path = repo_root / line
        rel = str(path.relative_to(repo_root))
        # Try to deinit in case it is a submodule; ignore errors
        run(["git", "submodule", "deinit", "-f", "--", rel], check=False)
        # Remove and stage changes (this updates .gitmodules for submodules)
        run(["git", "rm", "-fr", "--", rel], check=False)

    # 2) Replace personal gitconfig with example
    example = repo_root / "configs/git/gitconfig-personal.example"
    target = repo_root / "configs/git/gitconfig-personal"
    log("Replacing configs/git/gitconfig-personal with example")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(example, target)

    # 2b) Patch install.conf.yaml to drop links we removed
    install_conf = repo_root / "install.conf.yaml"
    log("Patching install.conf.yaml based on .publicignore")
    # Read ignore paths (assumes .publicignore exists)
    ignore_paths = [
        s.strip()
        for s in (repo_root / ".publicignore").read_text().splitlines()
        if s.strip() and not s.strip().startswith("#")
    ]

    def should_drop_link_line(line: str) -> bool:
        # Matches lines like: "    ~/.config/foo: configs/foo/bar"
        if ":" not in line:
            return False
        src = line.split(":", 1)[1].strip()
        if (src.startswith('"') and src.endswith('"')) or (
            src.startswith("'") and src.endswith("'")
        ):
            src = src[1:-1]
        return any(src == p or src.startswith(p + "/") for p in ignore_paths)

    lines = install_conf.read_text().splitlines()
    new_lines: list[str] = []
    skip_next_stdout = False
    for ln in lines:
        if skip_next_stdout:
            skip_next_stdout = False
            continue
        if "- command:" in ln and any(p in ln for p in ignore_paths):
            skip_next_stdout = True  # also drop the next stdout: line
            continue
        if should_drop_link_line(ln):
            continue
        new_lines.append(ln)

    if new_lines != lines:
        install_conf.write_text("\n".join(new_lines) + "\n")

    # 2c) Convert submodule SSH URLs to HTTPS for public access
    gitmodules = repo_root / ".gitmodules"
    if gitmodules.exists():
        log("Converting submodule URLs from SSH to HTTPS")
        content = gitmodules.read_text()
        # Convert git@github.com:user/repo.git to https://github.com/user/repo.git
        content = re.sub(
            r"url = git@github\.com:(.+?)\.git",
            r"url = https://github.com/\1.git",
            content,
        )
        gitmodules.write_text(content)

    # 3) First commit: all sanitization (this has HTTPS submodule URLs)
    run(["git", "add", "-A"])
    status = run(["git", "status", "--porcelain"], capture=True).stdout.strip()
    if not status:
        log("No changes after sanitization. Skipping commit/push.")
        return 0

    git_commit = [
        "git", "-c", "user.name=github-actions[bot]",
        "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com",
        "commit",
    ]
    run(git_commit + ["-m", f"chore(public): sync from {base} {short_sha} and sanitize"])

    # 4) Pin bootstrap.sh to the sanitized commit SHA (not main!)
    sanitized_sha = run(["git", "rev-parse", "HEAD"], capture=True).stdout.strip()
    bootstrap = repo_root / "scripts/bootstrap.sh"
    if bootstrap.exists():
        log(f"Pinning bootstrap.sh to sanitized commit {sanitized_sha}")
        content = bootstrap.read_text()
        # Replace entire clone block with init+fetch of specific commit
        old_clone = '''log "Cloning dotfiles ($DOTFILES_BRANCH) into $DOTFILES_DIR..."
git clone --depth=1 --branch "$DOTFILES_BRANCH" --single-branch "$DOTFILES_REPO" "$DOTFILES_DIR"'''
        new_clone = f'''log "Cloning dotfiles (commit {sanitized_sha}) into $DOTFILES_DIR..."
git init "$DOTFILES_DIR"
git -C "$DOTFILES_DIR" remote add origin "$DOTFILES_REPO"
git -C "$DOTFILES_DIR" fetch --depth=1 origin {sanitized_sha}
git -C "$DOTFILES_DIR" checkout FETCH_HEAD'''
        if old_clone not in content:
            raise RuntimeError("Could not find clone block in bootstrap.sh")
        content = content.replace(old_clone, new_clone)
        bootstrap.write_text(content)
        run(["git", "add", bootstrap])
        run(git_commit + ["-m", "chore(public): pin bootstrap.sh to sanitized commit"])

    if os.getenv("CI") == "true" or os.getenv("PUSH") == "1":
        log(f"Pushing {public} to origin (force)")
        run(["git", "push", "origin", public, "--force"])
    else:
        log("Local run detected and PUSH!=1; not pushing. Use PUSH=1 to push.")

    log("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
