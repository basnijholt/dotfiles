# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "requests",
# ]
# ///

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

SCRIPT_PATH = Path(__file__).with_name("update-overrides.py")
SPEC = importlib.util.spec_from_file_location("update_overrides", SCRIPT_PATH)
assert SPEC and SPEC.loader
update_overrides = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = update_overrides
SPEC.loader.exec_module(update_overrides)

placeholder = update_overrides.placeholder
HASHES = [placeholder("fixture", i) for i in range(4)]
CONTENT = f"""
    packageOverrides = pkgs: {{
      ollama =
        let
          llamaCppSrc = pkgs.fetchFromGitHub {{
            tag = "b100";
            hash = "{HASHES[0]}";
          }};
        in
        rec {{
          version = "0.35.1";
          src = pkgs.fetchFromGitHub {{ hash = "{HASHES[1]}"; }};
          vendorHash = "{HASHES[2]}";
        }};

      llama-swap =
        let
          version = "262";
        in
        pkgs.fetchurl {{ hash = "{HASHES[3]}"; }};
    }};
"""


class LatestReleaseTests(unittest.TestCase):
    @patch.object(update_overrides.requests, "get")
    def test_picks_highest_numeric_version_with_prefix(self, get):
        tags = ["v0.40.0-rc3", "v0.9.0", "v0.35.1", "b11430"]
        get.return_value = Mock(json=lambda: [{"tag_name": tag} for tag in tags])

        self.assertEqual(update_overrides.latest_release("o/r", "v"), "0.35.1")


class BumpTests(unittest.TestCase):
    @patch.object(update_overrides, "ollama_llama_cpp_tag", return_value="b200")
    @patch.object(update_overrides, "latest_release", return_value="0.36.0")
    def test_bumps_version_pin_and_only_this_packages_hashes(self, *_):
        updated = update_overrides.bump(CONTENT, "ollama")

        expected = CONTENT.replace("0.35.1", "0.36.0").replace("b100", "b200")
        for i in range(3):
            expected = expected.replace(HASHES[i], placeholder("ollama", i))
        self.assertEqual(updated, expected)

    @patch.object(update_overrides, "latest_release", return_value="262")
    def test_leaves_up_to_date_package_alone(self, _):
        self.assertEqual(update_overrides.bump(CONTENT, "llama-swap"), CONTENT)


class ResolveHashesTests(unittest.TestCase):
    @patch.object(update_overrides, "hash_mismatch")
    def test_resolves_only_remaining_placeholders(self, hash_mismatch):
        content = CONTENT.replace(HASHES[1], placeholder("ollama", 1)).replace(
            HASHES[2], placeholder("ollama", 2)
        )
        hash_mismatch.side_effect = [
            (placeholder("ollama", 2), "sha256-vendor"),
            (placeholder("ollama", 1), "sha256-src"),
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            file = Path(tmpdir) / "overrides.nix"
            with patch.object(update_overrides, "FILE", file):
                updated = update_overrides.resolve_hashes(content, "ollama")
            self.assertEqual(file.read_text(), updated)

        expected = CONTENT.replace(HASHES[1], "sha256-src")
        self.assertEqual(updated, expected.replace(HASHES[2], "sha256-vendor"))


class HashMismatchTests(unittest.TestCase):
    @patch.object(update_overrides.subprocess, "run")
    def test_parses_nix_hash_mismatch(self, run):
        stderr = (
            "error: hash mismatch in fixed-output derivation '/nix/store/x.drv':\n"
            "         specified: sha256-old=\n"
            "            got:    sha256-new=\n"
        )
        run.return_value = subprocess.CompletedProcess([], 1, "", stderr)

        self.assertEqual(
            update_overrides.hash_mismatch("ollama"), ("sha256-old=", "sha256-new=")
        )


if __name__ == "__main__":
    unittest.main()
