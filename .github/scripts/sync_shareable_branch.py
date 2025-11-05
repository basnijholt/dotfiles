#!/usr/bin/env python3
"""Minimal shareable-branch sync.

Steps:
 1) Checkout/reset PUBLIC_BRANCH from origin/BASE_BRANCH
 2) Remove exact paths listed in .publicignore (no globs)
 3) Replace configs/git/gitconfig-personal with example
 4) Commit and force-push PUBLIC_BRANCH (auto in CI; locally with PUSH=1)
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path


def log(msg: str) -> None:
    print(f"[sync-shareable] {msg}")


def run(args, *, check=True, capture=False):
    return subprocess.run(
        args,
        check=check,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )


def main() -> int:
    repo_root = Path(run(["git", "rev-parse", "--show-toplevel"], capture=True).stdout.strip())
    os.chdir(repo_root)

    base = os.getenv("BASE_BRANCH", "main")
    public = os.getenv("PUBLIC_BRANCH", "shareable")

    # Make sure we have the latest origin state
    run(["git", "fetch", "--prune", "origin"], check=False)
    short_sha = run(["git", "rev-parse", "--short", f"origin/{base}"], capture=True).stdout.strip()

    log(f"Base branch:    {base}")
    log(f"Shareable branch: {public}")
    log(f"Repo root:       {repo_root}")
    log(f"Checking out {public} from origin/{base} ({short_sha})")

    run(["git", "checkout", "-B", public, f"origin/{base}"])
    run(["git", "reset", "--hard", f"origin/{base}"])

    # 1) Remove listed items
    ignore_file = repo_root / ".publicignore"
    if ignore_file.exists():
        log("Applying removals from .publicignore")
        for raw in ignore_file.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            path = repo_root / line
            rel = str(path.relative_to(repo_root))
            # Try to deinit in case it is a submodule; ignore errors
            run(["git", "submodule", "deinit", "-f", "--", rel], check=False)
            # Remove from index
            run(["git", "rm", "-r", "-q", "--cached", "--ignore-unmatch", "--", rel], check=False)
            # Remove from working tree if present
            if path.is_dir():
                shutil.rmtree(path, ignore_errors=True)
            else:
                try:
                    path.unlink()
                except FileNotFoundError:
                    pass

    # 2) Replace personal gitconfig with example
    example = repo_root / "configs/git/gitconfig-personal.example"
    target = repo_root / "configs/git/gitconfig-personal"
    if example.exists():
        log("Replacing configs/git/gitconfig-personal with example")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(example, target)

    # 3) Commit and push if there are changes
    run(["git", "add", "-A"]) 
    status = run(["git", "status", "--porcelain"], capture=True).stdout.strip()
    if not status:
        log("No changes after sanitization. Skipping commit/push.")
        return 0

    run([
        "git", "-c", "user.name=github-actions[bot]",
        "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com",
        "commit", "-m", f"chore(shareable): sync from {base} {short_sha} and sanitize",
    ])

    if os.getenv("CI") == "true" or os.getenv("PUSH") == "1":
        log(f"Pushing {public} to origin (force)")
        run(["git", "push", "origin", public, "--force"]) 
    else:
        log("Local run detected and PUSH!=1; not pushing. Use PUSH=1 to push.")

    log("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
