# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "requests",
# ]
# ///

import contextlib
import importlib.util
import io
import subprocess
import sys
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
    def test_extracts_hash_from_either_output_stream(self, run):
        expected = "sha256-HT0QuIFJz5cgH2qinxhtyLEL/RrUpziZuntj/EDQtzI="

        for stream_name in ("stdout", "stderr"):
            with self.subTest(stream_name=stream_name):
                streams = {"stdout": "", "stderr": ""}
                streams[stream_name] = f"            got:    {expected}\n"
                run.return_value = subprocess.CompletedProcess(
                    args=["nix", "build"],
                    returncode=1,
                    **streams,
                )

                self.assertEqual(update_overrides.get_new_hash("ollama"), expected)

    @patch.object(update_overrides.subprocess, "run")
    def test_does_not_combine_partial_diagnostics_across_streams(self, run):
        unexpected = "sha256-HT0QuIFJz5cgH2qinxhtyLEL/RrUpziZuntj/EDQtzI="
        run.return_value = subprocess.CompletedProcess(
            args=["nix", "build"],
            returncode=1,
            stdout="got:",
            stderr=f"{unexpected}\n",
        )
        captured_stderr = io.StringIO()

        with contextlib.redirect_stderr(captured_stderr):
            actual = update_overrides.get_new_hash("ollama")

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
            actual = update_overrides.get_new_hash("ollama")

        self.assertIsNone(actual)
        self.assertIn("nix build exited with status 1", captured_stderr.getvalue())
        self.assertIn("copying source", captured_stderr.getvalue())
        self.assertIn("error: unable to download source", captured_stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
