import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
LAUNCHER = HERE / "vllm-swap.py"

FAKE = r"""
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

root = Path(os.environ["FAKE_ROOT"])
containers = root / "containers"
def marker(name):
    return containers / name

def cf(args):
    stack, action = args[3:5]
    name = "llama-swap-" + stack
    settings = json.loads((root / "controls.json").read_text())
    if action == "down":
        if stack in settings.get("down_fail", []):
            return 43
        marker(name).unlink(missing_ok=True)
        return 0
    service = args[-1]
    if service == "fa2-init":
        return 0
    (root / "port").write_text(os.environ["LLAMA_SWAP_PORT"])
    marker(name).touch()
    if settings.get("leader_race"):
        subprocess.Popen([sys.executable, __file__, "late", name])
        time.sleep(0.05)
        os.kill(os.getppid(), signal.SIGTERM)
        return 0
    while marker(name).exists():
        time.sleep(0.02)
    return int(json.loads((root / "controls.json").read_text()).get("vllm_exit", 0))

def docker(args):
    if json.loads((root / "controls.json").read_text()).get("docker_error"):
        print("daemon unavailable", file=sys.stderr)
        return 125
    if args[:2] != ["ps", "--format"]:
        return 64
    for path in containers.iterdir():
        print(path.name)
    return 0

if sys.argv[1:2] == ["late"]:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    time.sleep(0.5)
    marker(sys.argv[2]).touch()
    raise SystemExit(0)

kind = Path(sys.argv[0]).name
raise SystemExit(cf(sys.argv[1:]) if kind == "fake-cf" else docker(sys.argv[1:]))
"""


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix=".vllm-test-", dir=HERE)
        self.root = Path(self.temp.name)
        (self.root / "containers").mkdir()
        (self.root / "controls.json").write_text("{}")
        runtime = self.root / "fake.py"
        runtime.write_text(f"#!{sys.executable}\n" + FAKE)
        runtime.chmod(0o755)
        for name in ("fake-cf", "fake-docker"):
            (self.root / name).symlink_to(runtime)
        self.env = os.environ | {
            "FAKE_ROOT": str(self.root),
            "VLLM_SWAP_CF": str(self.root / "fake-cf"),
            "VLLM_SWAP_DOCKER": str(self.root / "fake-docker"),
            "VLLM_SWAP_CF_CONFIG": str(self.root / "cf.yaml"),
            "VLLM_SWAP_STATE_DIR": str(self.root / "state"),
            "VLLM_SWAP_STOP_TIMEOUT": "1",
        }
        self.process = None

    def tearDown(self):
        self.set_controls(down_fail=[])
        subprocess.run(
            self.command("cleanup"),
            env=self.env,
            capture_output=True,
            timeout=3,
            check=False,
        )
        if self.process and self.process.poll() is None:
            self.process.kill()
            self.process.wait(timeout=2)
        if self.process and self.process.stderr:
            self.process.stderr.close()
        self.temp.cleanup()

    def command(self, *args):
        return [sys.executable, str(LAUNCHER), *args]

    def invoke(self, *args):
        return subprocess.run(
            self.command(*args),
            env=self.env,
            capture_output=True,
            text=True,
            timeout=4,
            check=False,
        )

    def start(self, model="normal", port="18000"):
        self.process = subprocess.Popen(
            self.command("start", model, port),
            env=self.env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        return self.process

    def set_controls(self, **values):
        path = self.root / "controls.json"
        controls = json.loads(path.read_text()) | values
        replacement = path.with_suffix(".new")
        replacement.write_text(json.dumps(controls))
        replacement.replace(path)

    def marker(self, model):
        return self.root / "containers" / f"llama-swap-qwen38-{model}"

    def wait_for(self, predicate, timeout=2):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            if self.process.poll() is not None:
                _stdout, stderr = self.process.communicate()
                self.fail(
                    f"launcher exited early ({self.process.returncode}): {stderr}"
                )
            time.sleep(0.02)
        self.fail("timed out waiting for subprocess state")

    def test_attached_start_stays_alive_until_requested_stop(self):
        process = self.start(port="18123")
        self.wait_for(self.marker("normal").exists)
        self.assertEqual((self.root / "port").read_text(), "18123")
        self.assertIsNone(process.poll())

        self.assertEqual(self.invoke("stop", "normal").returncode, 0)
        self.assertEqual(process.wait(timeout=2), 0)

    def test_running_container_and_docker_failure_block_start(self):
        self.marker("normal").touch()
        conflict = self.invoke("start", "uncensored", "18001")
        self.assertNotEqual(conflict.returncode, 0)
        self.assertIn("already running", conflict.stderr)

        self.marker("normal").unlink()
        self.set_controls(docker_error=True)
        uncertain = self.invoke("start", "normal", "18000")
        self.assertNotEqual(uncertain.returncode, 0)
        self.assertIn("cannot list running containers", uncertain.stderr)

    def test_backend_crash_status_is_reported(self):
        self.set_controls(vllm_exit=23)
        process = self.start()
        self.wait_for(self.marker("normal").exists)
        self.marker("normal").unlink()

        _stdout, stderr = process.communicate(timeout=2)
        self.assertEqual(process.returncode, 23)
        self.assertIn("failed with status 23", stderr)

    def test_cancellation_as_cf_leader_exits_prevents_late_container(self):
        self.set_controls(leader_race=True)
        process = self.start()
        self.assertNotEqual(process.wait(timeout=2), 0)
        time.sleep(0.6)
        self.assertFalse(self.marker("normal").exists())

    def test_stop_for_other_model_does_not_stop_owner(self):
        process = self.start()
        self.wait_for(self.marker("normal").exists)

        self.assertEqual(self.invoke("stop", "uncensored").returncode, 0)
        self.assertTrue(self.marker("normal").exists())
        self.assertIsNone(process.poll())

    def test_failed_cleanup_leaves_survivor_that_blocks_next_start(self):
        process = self.start()
        self.wait_for(self.marker("normal").exists)
        self.set_controls(down_fail=["qwen38-normal"])

        process.send_signal(signal.SIGTERM)
        self.assertNotEqual(process.wait(timeout=3), 0)
        self.assertTrue(self.marker("normal").exists())
        blocked = self.invoke("start", "uncensored", "18001")
        self.assertNotEqual(blocked.returncode, 0)
        self.assertIn("already running", blocked.stderr)


if __name__ == "__main__":
    unittest.main()
