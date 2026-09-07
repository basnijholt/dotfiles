"""Integration checks for explicitly trusted private remotes."""

import hashlib
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import forbidden_words


class PrivateRemoteTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.config = self.root / "config" / "git"
        self.config.mkdir(parents=True)
        self.cache = self.root / "cache" / "git-forbidden-words"
        self.cache.mkdir(parents=True)
        self.environment = patch.dict(
            os.environ,
            {
                "XDG_CONFIG_HOME": str(self.root / "config"),
                "XDG_CACHE_HOME": str(self.root / "cache"),
                "GIT_CONFIG_GLOBAL": os.devnull,
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_FORBIDDEN_WORDS_VISIBILITY_TTL": "86400",
            },
        )
        self.environment.start()
        self.addCleanup(self.environment.stop)
        previous = Path.cwd()
        os.chdir(self.repo)
        self.addCleanup(os.chdir, previous)
        self.git("init", "--quiet")
        self.config.joinpath("forbidden-words").write_text(
            "confidentialmarker\tTest rule\n"
        )
        self.repo.joinpath("notes.md").write_text("confidentialmarker\n")
        self.git("add", "notes.md")
        self.trusted = "work:/work/private-notes.git"
        self.allowlist = self.config / "forbidden-words.private-remotes"

    def git(self, *args):
        return subprocess.run(
            ["git", *args], check=True, capture_output=True, text=True
        )

    def add_remote(self, name, url, visibility="UNKNOWN"):
        self.git("remote", "add", name, url)
        key = hashlib.sha256(url.encode()).hexdigest()[:20]
        (self.cache / f"{key}.json").write_text(
            json.dumps(
                {
                    "checked_at": int(time.time()),
                    "visibility": visibility,
                }
            )
        )

    def check_hook(self):
        return forbidden_words.run_hook("pre-commit", [])

    def test_exact_private_remote_allows_commit_despite_cached_unknown(self):
        self.add_remote("work", self.trusted)
        self.allowlist.write_text(f"# Explicit private remote\n\n{self.trusted}\n")
        self.assertEqual(self.check_hook(), 0)

    def test_unknown_remote_without_allowlist_stays_blocked(self):
        self.add_remote("work", self.trusted)
        self.assertEqual(self.check_hook(), 1)

    def test_allowlist_is_exact_not_a_prefix_or_glob(self):
        self.add_remote("work", self.trusted + "-public")
        self.allowlist.write_text(f"{self.trusted}\nwork:*\n")
        self.assertEqual(self.check_hook(), 1)

    def test_public_origin_is_not_exempted_by_trusted_secondary_remote(self):
        self.add_remote("origin", "https://github.com/example/public.git", "PUBLIC")
        self.add_remote("work", self.trusted)
        self.allowlist.write_text(self.trusted + "\n")
        self.assertEqual(self.check_hook(), 1)

    def test_unknown_secondary_remote_prevents_explicit_trust(self):
        self.add_remote("work", self.trusted)
        self.add_remote("zbackup", "elsewhere:/public.git")
        self.allowlist.write_text(self.trusted + "\n")
        self.assertEqual(self.check_hook(), 1)

    def test_untrusted_push_destination_prevents_explicit_trust(self):
        self.add_remote("work", self.trusted)
        self.git(
            "remote", "set-url", "--add", "--push", "work", "elsewhere:/public.git"
        )
        self.allowlist.write_text(self.trusted + "\n")
        self.assertEqual(self.check_hook(), 1)

    def test_removing_allowlist_restores_protection_without_cache_expiry(self):
        self.add_remote("work", self.trusted)
        self.allowlist.write_text(self.trusted + "\n")
        self.assertEqual(self.check_hook(), 0)
        self.allowlist.unlink()
        self.assertEqual(self.check_hook(), 1)

    def test_trusted_remote_also_allows_commit_message(self):
        self.add_remote("work", self.trusted)
        self.allowlist.write_text(self.trusted + "\n")
        message = self.root / "message"
        message.write_text("confidentialmarker\n")
        self.assertEqual(forbidden_words.run_hook("commit-msg", [str(message)]), 0)


if __name__ == "__main__":
    unittest.main()
