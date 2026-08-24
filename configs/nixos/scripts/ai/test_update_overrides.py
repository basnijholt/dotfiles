# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "requests",
# ]
# ///

import contextlib
import importlib.util
import io
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT_PATH = Path(__file__).with_name("update-overrides.py")
SPEC = importlib.util.spec_from_file_location("update_overrides", SCRIPT_PATH)
assert SPEC and SPEC.loader
update_overrides = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = update_overrides
SPEC.loader.exec_module(update_overrides)


class GetNewHashTests(unittest.TestCase):
    @patch.object(update_overrides.subprocess, "run")
    def test_extracts_hash_mismatch_from_either_output_stream(self, run):
        specified = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        got = "sha256-HT0QuIFJz5cgH2qinxhtyLEL/RrUpziZuntj/EDQtzI="

        for stream_name in ("stdout", "stderr"):
            with self.subTest(stream_name=stream_name):
                streams = {"stdout": "", "stderr": ""}
                streams[stream_name] = (
                    f"      specified: {specified}\n             got: {got}\n"
                )
                run.return_value = subprocess.CompletedProcess(
                    args=["nix", "build"],
                    returncode=1,
                    **streams,
                )

                self.assertEqual(
                    update_overrides.get_hash_mismatch("ollama"), (specified, got)
                )

    @patch.object(update_overrides.subprocess, "run")
    def test_does_not_combine_partial_diagnostics_across_streams(self, run):
        specified = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        got = "sha256-HT0QuIFJz5cgH2qinxhtyLEL/RrUpziZuntj/EDQtzI="
        run.return_value = subprocess.CompletedProcess(
            args=["nix", "build"],
            returncode=1,
            stdout=f"specified: {specified}\n",
            stderr=f"got: {got}\n",
        )
        captured_stderr = io.StringIO()

        with contextlib.redirect_stderr(captured_stderr):
            actual = update_overrides.get_hash_mismatch("ollama")

        self.assertIsNone(actual)

    @patch.object(update_overrides.subprocess, "run")
    def test_reports_build_failure_output_when_hash_is_missing(self, run):
        run.return_value = subprocess.CompletedProcess(
            args=["nix", "build"],
            returncode=1,
            stdout="copying source\n",
            stderr="error: unable to download source\n",
        )
        captured_stderr = io.StringIO()

        with contextlib.redirect_stderr(captured_stderr):
            actual = update_overrides.get_hash_mismatch("ollama")

        self.assertIsNone(actual)
        self.assertIn("nix build exited with status 1", captured_stderr.getvalue())
        self.assertIn("copying source", captured_stderr.getvalue())
        self.assertIn("error: unable to download source", captured_stderr.getvalue())


class ReplaceHashesTests(unittest.TestCase):
    def test_uses_distinct_dummy_hashes_for_each_slot(self):
        content = """
        block = {
          src = pkgs.fetchFromGitHub {
            hash = "sha256-source";
          };
          vendorHash = "sha256-vendor";
        };
        """

        updated = update_overrides.replace_hashes_in_block(
            content, content.index("block ="), 2
        )
        hashes = re.findall(r'sha256-[^"]+', updated)

        self.assertEqual(len(hashes), 2)
        self.assertNotEqual(hashes[0], hashes[1])

    def test_does_not_replace_hashes_in_the_next_package(self):
        content = """
        first = {
          hash = "sha256-first";
        };
        second = {
          hash = "sha256-second";
        };
        """

        with self.assertRaises(ValueError):
            update_overrides.replace_hashes_in_block(content, 1, 2, "first")

    def test_finds_package_block_from_a_nested_version_match(self):
        content = """
        llama-swap = pkgs.runCommand "llama-swap" { } ''
          url = "https://example.com/llama-swap";
          hash = "sha256-first";
        '';
        """

        try:
            updated = update_overrides.replace_hashes_in_block(
                content, content.index("https://example.com"), 1, "llama-swap"
            )
        except ValueError:
            updated = content

        self.assertNotIn("sha256-first", updated)


class ResolveHashesTests(unittest.TestCase):
    @patch.object(update_overrides, "get_hash_mismatch")
    def test_resumes_only_unresolved_package_hashes(self, get_hash_mismatch):
        existing = "sha256-existing"
        first_dummy = update_overrides.dummy_hash("ollama", 1)
        second_dummy = update_overrides.dummy_hash("ollama", 2)
        first_resolved = "sha256-first-resolved"
        second_resolved = "sha256-second-resolved"
        get_hash_mismatch.side_effect = [
            (first_dummy, first_resolved),
            (second_dummy, second_resolved),
            (existing, "sha256-wrongly-replaced"),
        ]
        content = f"{existing}\n{first_dummy}\n{second_dummy}\n"
        package = update_overrides.Package(
            name="ollama",
            owner="ollama",
            repo="ollama",
            tag_prefix="v",
            version_pattern=re.compile("unused"),
            hash_count=3,
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "overrides.nix"
            file_path.write_text(content)
            updated = update_overrides.resolve_hashes(file_path, content, package)

        self.assertEqual(updated, f"{existing}\n{first_resolved}\n{second_resolved}\n")


if __name__ == "__main__":
    unittest.main()
