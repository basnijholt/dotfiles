#!/usr/bin/env python3

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

GIT_LFS_HOOKS = {"post-checkout", "post-commit", "post-merge", "pre-push"}


def git_common_hook(hook_name: str) -> Path | None:
    result = subprocess.run(
        ["git", "rev-parse", "--git-common-dir"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    common_dir = Path(result.stdout.strip())
    if not common_dir.is_absolute():
        common_dir = Path.cwd() / common_dir
    return common_dir / "hooks" / hook_name


def run_forwarder(hook_name: str, arguments: list[str], current_hook: Path) -> int:
    stdin = sys.stdin.buffer.read()
    local_hook = git_common_hook(hook_name)
    if (
        local_hook is not None
        and os.access(local_hook, os.X_OK)
        and local_hook.resolve() != current_hook.resolve()
    ):
        return subprocess.run(
            [str(local_hook), *arguments], check=False, input=stdin
        ).returncode
    if hook_name in GIT_LFS_HOOKS and shutil.which("git-lfs") is not None:
        return subprocess.run(
            ["git", "lfs", hook_name, *arguments], check=False, input=stdin
        ).returncode
    return 0


if __name__ == "__main__":
    invoked_path = Path(sys.argv[0])
    raise SystemExit(run_forwarder(invoked_path.name, sys.argv[1:], invoked_path))
