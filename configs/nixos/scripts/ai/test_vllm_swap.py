import json
import os
import signal
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
LAUNCHER = SCRIPT_DIR / "vllm-swap.py"

FAKE_RUNTIME = r"""
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

root = Path(os.environ["FAKE_STATE_DIR"])
containers = root / "containers"
containers.mkdir(exist_ok=True)
controls_path = root / "controls.json"
log_path = root / "calls.jsonl"


def controls():
    try:
        return json.loads(controls_path.read_text())
    except FileNotFoundError:
        return {}


def marker(container):
    return containers / container


def append_log(kind, args):
    record = {
        "kind": kind,
        "args": args,
        "port": os.environ.get("LLAMA_SWAP_PORT"),
    }
    with log_path.open("a") as stream:
        stream.write(json.dumps(record) + "\n")


def stack_container(stack):
    return {
        "qwen38-normal": "llama-swap-qwen38-normal",
        "qwen38-uncensored": "llama-swap-qwen38-uncensored",
    }[stack]


def child_up(container):
    settings = controls()
    if settings.get("up_ignore_term"):
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
    time.sleep(float(settings.get("up_delay", 0)))
    marker(container).touch()
    if container in settings.get("up_fail_after_create", []):
        return 42
    return 0


def cf(args):
    append_log("cf", args)
    if len(args) < 5 or args[:3] != ["compose", "--config", str(root / "cf.yaml")]:
        print("unexpected cf arguments", file=sys.stderr)
        return 64
    stack, command = args[3:5]
    container = stack_container(stack)
    if command == "up":
        child = subprocess.Popen([sys.executable, __file__, "child-up", container])
        if controls().get("up_signal_parent_then_exit"):
            time.sleep(0.05)
            os.kill(os.getppid(), signal.SIGTERM)
            return 0
        return child.wait()
    if command == "down":
        settings = controls()
        if container in settings.get("down_fail", []):
            print("injected down failure", file=sys.stderr)
            return 43
        marker(container).unlink(missing_ok=True)
        return 0
    print("unexpected compose command", file=sys.stderr)
    return 64


def docker(args):
    append_log("docker", args)
    if args[:2] == ["inspect", "--format"] and len(args) == 4:
        container = args[3]
        settings = controls()
        if settings.get("inspect_error"):
            print("cannot connect to Docker daemon", file=sys.stderr)
            return 125
        if marker(container).exists():
            print("true")
            return 0
        print(f"Error: No such object: {container}", file=sys.stderr)
        return 1
    if args[:1] == ["wait"] and len(args) == 2:
        container = args[1]
        while marker(container).exists():
            time.sleep(0.02)
        print("0")
        return 0
    print("unexpected docker arguments", file=sys.stderr)
    return 64


if sys.argv[1:2] == ["child-up"]:
    raise SystemExit(child_up(sys.argv[2]))

kind = Path(sys.argv[0]).name
if kind == "fake-cf":
    raise SystemExit(cf(sys.argv[1:]))
if kind == "fake-docker":
    raise SystemExit(docker(sys.argv[1:]))
raise SystemExit(64)
"""


class VllmSwapLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory(
            prefix=".vllm-swap-test-", dir=SCRIPT_DIR
        )
        self.root = Path(self.tempdir.name)
        self.state_dir = self.root / "launcher-state"
        self.state_dir.mkdir()
        self.containers = self.root / "containers"
        self.containers.mkdir()
        (self.root / "controls.json").write_text("{}")
        (self.root / "cf.yaml").write_text("stacks: {}\n")
        self.processes = []

        runtime = self.root / "fake-runtime.py"
        runtime.write_text(f"#!{sys.executable}\n" + textwrap.dedent(FAKE_RUNTIME))
        runtime.chmod(0o755)
        self.cf = self.root / "fake-cf"
        self.docker = self.root / "fake-docker"
        self.cf.symlink_to(runtime)
        self.docker.symlink_to(runtime)

        config = {
            "cf": str(self.cf),
            "cfConfig": str(self.root / "cf.yaml"),
            "docker": str(self.docker),
            "stateDir": str(self.state_dir),
            "stopTimeout": 2,
            "legacyContainers": ["club-3090-vllm"],
            "models": {
                "normal": {
                    "stack": "qwen38-normal",
                    "service": "vllm",
                    "container": "llama-swap-qwen38-normal",
                },
                "uncensored": {
                    "stack": "qwen38-uncensored",
                    "service": "vllm",
                    "container": "llama-swap-qwen38-uncensored",
                },
            },
        }
        self.config_path = self.root / "config.json"
        self.config_path.write_text(json.dumps(config))
        self.env = os.environ.copy()
        self.env["FAKE_STATE_DIR"] = str(self.root)

    def tearDown(self):
        self.set_controls(down_fail=[])
        if LAUNCHER.exists():
            subprocess.run(
                self.command("cleanup"),
                env=self.env,
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
        for process in self.processes:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=2)
            if process.stdout:
                process.stdout.close()
            if process.stderr:
                process.stderr.close()
        self.tempdir.cleanup()

    def command(self, *args):
        return [sys.executable, str(LAUNCHER), "--config", str(self.config_path), *args]

    def run_launcher(self, *args, timeout=5):
        return subprocess.run(
            self.command(*args),
            env=self.env,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )

    def start_launcher(self, model="normal", port="18000"):
        process = subprocess.Popen(
            self.command("start", model, port),
            env=self.env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.processes.append(process)
        return process

    def set_controls(self, **values):
        path = self.root / "controls.json"
        current = json.loads(path.read_text())
        current.update(values)
        replacement = path.with_suffix(".new")
        replacement.write_text(json.dumps(current))
        replacement.replace(path)

    def marker(self, model):
        name = {
            "normal": "llama-swap-qwen38-normal",
            "uncensored": "llama-swap-qwen38-uncensored",
            "legacy": "club-3090-vllm",
        }[model]
        return self.containers / name

    def wait_for(self, predicate, process=None, timeout=3):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            if process is not None and process.poll() is not None:
                stdout, stderr = process.communicate()
                self.fail(
                    f"launcher exited early with {process.returncode}:\n"
                    f"stdout: {stdout}\nstderr: {stderr}"
                )
            time.sleep(0.02)
        self.fail("timed out waiting for subprocess state")

    def calls(self):
        path = self.root / "calls.jsonl"
        if not path.exists():
            return []
        return [json.loads(line) for line in path.read_text().splitlines()]

    def test_start_stays_foreground_until_requested_model_is_stopped(self):
        process = self.start_launcher(port="18123")
        self.wait_for(self.marker("normal").exists, process)

        self.assertIsNone(process.poll())
        up_call = next(
            call
            for call in self.calls()
            if call["kind"] == "cf" and "up" in call["args"]
        )
        self.assertEqual(
            up_call["args"],
            [
                "compose",
                "--config",
                str(self.root / "cf.yaml"),
                "qwen38-normal",
                "up",
                "-d",
                "vllm",
            ],
        )
        self.assertEqual(up_call["port"], "18123")

        stopped = self.run_launcher("stop", "normal")
        self.assertEqual(stopped.returncode, 0, stopped.stderr)
        self.assertEqual(process.wait(timeout=3), 0)
        self.assertFalse(self.marker("normal").exists())

    def test_second_model_is_rejected_while_first_owns_lock(self):
        process = self.start_launcher()
        self.wait_for(self.marker("normal").exists, process)

        second = self.run_launcher("start", "uncensored", "18001")

        self.assertNotEqual(second.returncode, 0)
        self.assertFalse(self.marker("uncensored").exists())

    def test_surviving_container_after_wrapper_sigkill_blocks_next_start(self):
        process = self.start_launcher()
        self.wait_for(self.marker("normal").exists, process)
        process.kill()
        process.wait(timeout=3)
        self.assertTrue(self.marker("normal").exists())

        second = self.run_launcher("start", "uncensored", "18001")

        self.assertNotEqual(second.returncode, 0)
        self.assertFalse(self.marker("uncensored").exists())

    def test_legacy_container_blocks_start(self):
        self.marker("legacy").touch()

        result = self.run_launcher("start", "normal", "18000")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("conflicting container is running", result.stderr)
        self.assertFalse(self.marker("normal").exists())

    def test_docker_inspection_error_blocks_start(self):
        self.set_controls(inspect_error=True)

        result = self.run_launcher("start", "normal", "18000")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot determine container state", result.stderr)
        self.assertFalse(self.marker("normal").exists())

    def test_failed_start_removes_partially_created_container(self):
        self.set_controls(up_fail_after_create=["llama-swap-qwen38-normal"])

        result = self.run_launcher("start", "normal", "18000")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("failed to start model normal", result.stderr)
        self.assertTrue(
            any(
                call["kind"] == "cf" and "down" in call["args"] for call in self.calls()
            )
        )
        self.assertFalse(self.marker("normal").exists())

    def test_sigterm_during_start_reaps_child_before_cleanup(self):
        self.set_controls(up_delay=0.8, up_ignore_term=True)
        process = self.start_launcher()
        self.wait_for(
            lambda: any(
                call["kind"] == "cf" and "up" in call["args"] for call in self.calls()
            ),
            process,
        )

        process.send_signal(signal.SIGTERM)
        self.assertNotEqual(process.wait(timeout=3), 0)
        time.sleep(0.9)

        self.assertFalse(self.marker("normal").exists())

    def test_cancellation_as_start_leader_exits_reaps_descendant(self):
        self.set_controls(
            up_delay=0.8,
            up_ignore_term=True,
            up_signal_parent_then_exit=True,
        )

        process = self.start_launcher()
        self.assertNotEqual(process.wait(timeout=3), 0)
        time.sleep(0.9)

        self.assertFalse(self.marker("normal").exists())

    def test_stop_for_other_model_does_not_stop_current_model(self):
        process = self.start_launcher()
        self.wait_for(self.marker("normal").exists, process)

        wrong_stop = self.run_launcher("stop", "uncensored")

        self.assertEqual(wrong_stop.returncode, 0, wrong_stop.stderr)
        self.assertTrue(self.marker("normal").exists())
        self.assertIsNone(process.poll())

    def test_failed_cleanup_is_reported_and_survivor_blocks_next_start(self):
        process = self.start_launcher()
        self.wait_for(self.marker("normal").exists, process)
        self.set_controls(down_fail=["llama-swap-qwen38-normal"])

        process.send_signal(signal.SIGTERM)
        self.assertNotEqual(process.wait(timeout=3), 0)
        self.assertTrue(self.marker("normal").exists())

        second = self.run_launcher("start", "uncensored", "18001")
        self.assertNotEqual(second.returncode, 0)
        self.assertFalse(self.marker("uncensored").exists())

    def test_failed_stop_reports_surviving_container_and_blocks_start(self):
        self.marker("normal").touch()
        self.set_controls(down_fail=["llama-swap-qwen38-normal"])

        stopped = self.run_launcher("stop", "normal")

        self.assertNotEqual(stopped.returncode, 0)
        self.assertIn("container survived cleanup", stopped.stderr)
        second = self.run_launcher("start", "uncensored", "18001")
        self.assertNotEqual(second.returncode, 0)
        self.assertIn("conflicting container is running", second.stderr)
        self.assertFalse(self.marker("uncensored").exists())

    def test_invalid_model_and_port_are_rejected_without_external_calls(self):
        cases = [
            (("start", "missing", "18000"), "unknown model"),
            (("start", "normal", "text"), "port must be an integer"),
            (("start", "normal", "1023"), "port must be in 1024..65535"),
            (("start", "normal", "65536"), "port must be in 1024..65535"),
            (("stop", "missing"), "unknown model"),
        ]
        for args, diagnostic in cases:
            with self.subTest(args=args):
                result = self.run_launcher(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
