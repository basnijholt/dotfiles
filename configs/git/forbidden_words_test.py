#!/usr/bin/env python3

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HOOKS_DIR = Path(__file__).with_name("hooks")


class ForbiddenWordsHookTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.repo = self.root / "repo"
        self.config_dir = self.root / "config" / "git"
        self.cache_dir = self.root / "cache"
        self.bin_dir = self.root / "bin"
        self.calls_file = self.root / "gh-calls"
        self.repo.mkdir()
        self.config_dir.mkdir(parents=True)
        self.bin_dir.mkdir()

        self.env = os.environ.copy()
        self.env.update(
            {
                "PATH": f"{self.bin_dir}:{self.env['PATH']}",
                "XDG_CONFIG_HOME": str(self.root / "config"),
                "XDG_CACHE_HOME": str(self.cache_dir),
                "GH_CALLS_FILE": str(self.calls_file),
                "GH_VISIBILITY": "PUBLIC",
            }
        )

        self._run(["git", "init", "-q"])
        self._run(["git", "config", "user.name", "Hook Test"])
        self._run(["git", "config", "user.email", "hook@example.com"])
        self._run(["git", "remote", "add", "origin", "git@github.com:example/repo.git"])

        fake_gh = self.bin_dir / "gh"
        fake_gh.write_text(
            "#!/bin/sh\n"
            'printf "x" >> "$GH_CALLS_FILE"\n'
            'if [ "${GH_FAIL:-0}" = 1 ]; then exit 1; fi\n'
            'printf "%s\\n" "${GH_VISIBILITY:-PUBLIC}"\n'
        )
        fake_gh.chmod(0o755)

        self._write_rules("acme-secret\tUse the public placeholder instead.\n")

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def _run(
        self,
        command: list[str],
        *,
        env: dict[str, str] | None = None,
        check: bool = True,
        input_text: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            command,
            cwd=self.repo,
            env=env or self.env,
            check=check,
            capture_output=True,
            input=input_text,
            text=True,
        )

    def _write_rules(self, contents: str, *, private: bool = False) -> None:
        suffix = ".private" if private else ""
        (self.config_dir / f"forbidden-words{suffix}").write_text(contents)

    def _commit_without_hooks(self, message: str = "baseline") -> None:
        self._run(["git", "add", "."])
        self._run(["git", "commit", "-q", "--no-verify", "-m", message])

    def _stage(self, path: str, contents: str) -> None:
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(contents)
        self._run(["git", "add", "--", path])

    def _stage_bytes(self, path: str, contents: bytes) -> None:
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(contents)
        self._run(["git", "add", "--", path])

    def _hook(
        self,
        hook_name: str,
        *arguments: str,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return self._run(
            [str(HOOKS_DIR / hook_name), *arguments],
            env=env,
            check=False,
        )

    def _forward_hook(
        self,
        hook_name: str,
        *arguments: str,
        env: dict[str, str] | None = None,
        input_text: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        entrypoint = self.root / hook_name
        entrypoint.symlink_to(HOOKS_DIR / "forward_hook.py")
        return self._run(
            [str(entrypoint), *arguments],
            env=env,
            check=False,
            input_text=input_text,
        )

    def test_public_repo_blocks_forbidden_word_in_added_lines_with_reason(self) -> None:
        self._stage("source file.txt", "safe\nACME-SECRET\n")

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 1)
        self.assertIn("acme-secret", result.stderr.lower())
        self.assertIn("Use the public placeholder instead.", result.stderr)
        self.assertIn("source file.txt", result.stderr)
        self.assertNotIn("ACME-SECRET\n", result.stderr)

    def test_existing_forbidden_word_in_untouched_lines_is_allowed(self) -> None:
        self._stage("source.txt", "acme-secret\n")
        self._commit_without_hooks()
        self._stage("source.txt", "acme-secret\nsafe addition\n")

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_added_line_starting_with_two_pluses_is_checked(self) -> None:
        self._stage("source.txt", "++ acme-secret\n")

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 1)
        self.assertIn("Use the public placeholder instead.", result.stderr)

    def test_forbidden_word_in_staged_path_is_checked(self) -> None:
        self._stage("acme-secret/source.txt", "safe\n")

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 1)
        self.assertIn("Use the public placeholder instead.", result.stderr)
        self.assertIn("acme-secret/source.txt", result.stderr)

    def test_forbidden_word_in_binary_classified_addition_is_checked(self) -> None:
        self._stage_bytes("asset.bin", b"\xffacme-secret\n")

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 1)
        self.assertIn("Use the public placeholder instead.", result.stderr)

    def test_commit_message_is_checked(self) -> None:
        message = self.root / "COMMIT_EDITMSG"
        message.write_text("mention Acme-Secret here\n")

        result = self._hook("commit-msg", str(message))

        self.assertEqual(result.returncode, 1)
        self.assertIn("Use the public placeholder instead.", result.stderr)
        self.assertIn("commit message", result.stderr)

    def test_private_overlay_rules_are_loaded(self) -> None:
        self._write_rules(
            "private-name\tKeep this machine-specific name private.\n", private=True
        )
        self._stage("source.txt", "private-name\n")

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 1)
        self.assertIn("Keep this machine-specific name private.", result.stderr)

    def test_private_repo_skips_checks_and_caches_private_visibility(self) -> None:
        self._stage("source.txt", "acme-secret\n")
        private_env = self.env | {"GH_VISIBILITY": "PRIVATE"}

        first = self._hook("pre-commit", env=private_env)
        second = self._hook("pre-commit", env=self.env | {"GH_VISIBILITY": "PUBLIC"})

        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(self.calls_file.read_text(), "x")

    def test_public_visibility_is_cached(self) -> None:
        self._stage("source.txt", "acme-secret\n")

        first = self._hook("pre-commit")
        second = self._hook("pre-commit", env=self.env | {"GH_FAIL": "1"})

        self.assertEqual(first.returncode, 1)
        self.assertEqual(second.returncode, 1)
        self.assertEqual(self.calls_file.read_text(), "x")

    def test_expired_visibility_cache_is_refreshed(self) -> None:
        self._stage("source.txt", "acme-secret\n")
        private_env = self.env | {"GH_VISIBILITY": "PRIVATE"}
        first = self._hook("pre-commit", env=private_env)

        refreshed_env = self.env | {
            "GH_VISIBILITY": "PUBLIC",
            "GIT_FORBIDDEN_WORDS_VISIBILITY_TTL": "0",
        }
        second = self._hook("pre-commit", env=refreshed_env)

        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 1)
        self.assertEqual(self.calls_file.read_text(), "xx")

    def test_unknown_visibility_is_treated_as_public(self) -> None:
        self._stage("source.txt", "acme-secret\n")

        result = self._hook("pre-commit", env=self.env | {"GH_FAIL": "1"})

        self.assertEqual(result.returncode, 1)
        self.assertIn("Use the public placeholder instead.", result.stderr)

    def test_unusable_cache_does_not_disable_checks(self) -> None:
        self._stage("source.txt", "acme-secret\n")
        unusable_cache_env = self.env | {"XDG_CACHE_HOME": "/dev/null"}

        result = self._hook("pre-commit", env=unusable_cache_env)

        self.assertEqual(result.returncode, 1)
        self.assertIn("Use the public placeholder instead.", result.stderr)

    def test_repo_local_hook_exit_status_is_preserved(self) -> None:
        self._stage("source.txt", "safe\n")
        local_hook = self.repo / ".git" / "hooks" / "pre-commit"
        local_hook.write_text("#!/bin/sh\nexit 42\n")
        local_hook.chmod(0o755)

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 42)

    def test_pre_commit_framework_runs_when_repo_hook_is_missing(self) -> None:
        self._stage(".pre-commit-config.yaml", "repos: []\n")
        self._stage("source.txt", "safe\n")
        marker = self.root / "pre-commit-called"
        fake_pre_commit = self.bin_dir / "pre-commit"
        fake_pre_commit.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" > "$PRE_COMMIT_MARKER"\nexit 23\n'
        )
        fake_pre_commit.chmod(0o755)

        result = self._hook(
            "pre-commit", env=self.env | {"PRE_COMMIT_MARKER": str(marker)}
        )

        self.assertEqual(result.returncode, 23)
        self.assertEqual(marker.read_text(), "run --hook-stage pre-commit\n")

    def test_commit_msg_framework_receives_message_file(self) -> None:
        self._stage(".pre-commit-config.yaml", "repos: []\n")
        message = self.root / "COMMIT_EDITMSG"
        message.write_text("safe message\n")
        marker = self.root / "pre-commit-called"
        fake_pre_commit = self.bin_dir / "pre-commit"
        fake_pre_commit.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" > "$PRE_COMMIT_MARKER"\nexit 24\n'
        )
        fake_pre_commit.chmod(0o755)

        result = self._hook(
            "commit-msg",
            str(message),
            env=self.env | {"PRE_COMMIT_MARKER": str(marker)},
        )

        self.assertEqual(result.returncode, 24)
        self.assertEqual(
            marker.read_text(),
            f"run --hook-stage commit-msg --commit-msg-filename {message}\n",
        )

    def test_repo_local_pre_commit_cannot_stage_forbidden_content_after_scan(
        self,
    ) -> None:
        self._stage("source.txt", "safe\n")
        local_hook = self.repo / ".git" / "hooks" / "pre-commit"
        local_hook.write_text(
            "#!/bin/sh\n"
            "printf 'acme-secret\\n' > generated.txt\n"
            "git add generated.txt\n"
        )
        local_hook.chmod(0o755)

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 1)
        self.assertIn("generated.txt", result.stderr)

    def test_repo_local_commit_msg_cannot_rewrite_message_after_scan(self) -> None:
        message = self.root / "COMMIT_EDITMSG"
        message.write_text("safe message\n")
        local_hook = self.repo / ".git" / "hooks" / "commit-msg"
        local_hook.write_text("#!/bin/sh\nprintf 'acme-secret\\n' > \"$1\"\n")
        local_hook.chmod(0o755)

        result = self._hook("commit-msg", str(message))

        self.assertEqual(result.returncode, 1)
        self.assertIn("commit message", result.stderr)

    def test_generic_forwarder_runs_matching_repo_local_hook(self) -> None:
        marker = self.root / "local-hook-stdin"
        local_hook = self.repo / ".git" / "hooks" / "pre-push"
        local_hook.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" > "$LOCAL_HOOK_MARKER"\n'
            'cat >> "$LOCAL_HOOK_MARKER"\nexit 43\n'
        )
        local_hook.chmod(0o755)

        result = self._forward_hook(
            "pre-push",
            "origin",
            "https://example.com/repo.git",
            env=self.env | {"LOCAL_HOOK_MARKER": str(marker)},
            input_text="refs\n",
        )

        self.assertEqual(result.returncode, 43)
        self.assertEqual(
            marker.read_text(), "origin https://example.com/repo.git\nrefs\n"
        )

    def test_generic_forwarder_runs_git_lfs_when_local_hook_is_missing(self) -> None:
        marker = self.root / "git-lfs-called"
        fake_git_lfs = self.bin_dir / "git-lfs"
        fake_git_lfs.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" > "$GIT_LFS_MARKER"\nexit 0\n'
        )
        fake_git_lfs.chmod(0o755)

        result = self._forward_hook(
            "post-checkout",
            "old-oid",
            "new-oid",
            "1",
            env=self.env | {"GIT_LFS_MARKER": str(marker)},
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(marker.read_text(), "post-checkout old-oid new-oid 1\n")

    def test_rules_file_can_contain_the_forbidden_word(self) -> None:
        rules = self.repo / "configs" / "git" / "forbidden-words"
        rules.parent.mkdir(parents=True)
        rules.write_text("acme-secret\tUse the public placeholder instead.\n")
        (self.config_dir / "forbidden-words").unlink()
        (self.config_dir / "forbidden-words").symlink_to(rules)
        self._run(["git", "add", "configs/git/forbidden-words"])

        result = self._hook("pre-commit")

        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
