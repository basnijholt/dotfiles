#!/usr/bin/env python3
"""Tests for the Codex git safety hook."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
HOOK = REPO_ROOT / "configs" / "codex" / "hooks" / "block-git-rewrites.py"


def run_hook(command: str, tool_name: str = "Bash") -> subprocess.CompletedProcess[str]:
    payload = {
        "tool_name": tool_name,
        "tool_input": {
            "command": command,
        },
    }
    return subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        check=False,
        cwd=REPO_ROOT,
    )


class CodexHookTests(unittest.TestCase):
    def test_blocks_git_commit_amend(self) -> None:
        result = run_hook("git commit --amend")

        self.assertEqual(result.returncode, 2)
        self.assertIn("git commit --amend is not allowed", result.stderr)

    def test_blocks_force_push(self) -> None:
        result = run_hook("git push --force-with-lease")

        self.assertEqual(result.returncode, 2)
        self.assertIn("git push --force", result.stderr)

    def test_allows_safe_bash_command(self) -> None:
        result = run_hook("git status --short")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")

    def test_ignores_non_bash_tools(self) -> None:
        result = run_hook("git commit --amend", tool_name="apply_patch")

        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
