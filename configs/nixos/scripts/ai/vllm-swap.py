#!/usr/bin/env python3

import argparse
import fcntl
import os
import signal
import subprocess
import sys
from contextlib import suppress
from pathlib import Path

CF = os.environ.get("VLLM_SWAP_CF", "cf")
DOCKER = os.environ.get("VLLM_SWAP_DOCKER", "docker")
CF_CONFIG = os.environ.get("VLLM_SWAP_CF_CONFIG", "/etc/llama-swap/compose-farm.yaml")
STATE_DIR = Path(os.environ.get("VLLM_SWAP_STATE_DIR", "/run/llama-swap-vllm"))
STOP_TIMEOUT = os.environ.get("VLLM_SWAP_STOP_TIMEOUT", "90")
STACKS = {"normal": "qwen38-normal", "uncensored": "qwen38-uncensored"}
CONTAINERS = {
    "llama-swap-qwen38-normal",
    "llama-swap-qwen38-uncensored",
    "club-3090-vllm",
}
CANCEL_SIGNAL = None


class Cancelled(Exception):
    pass


def port_number(value):
    try:
        port = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("port must be an integer") from error
    if not 1024 <= port <= 65535:
        raise argparse.ArgumentTypeError("port must be in 1024..65535")
    return port


def compose(stack, *args):
    return [CF, "compose", "--config", CF_CONFIG, stack, *args]


def describe(error):
    if isinstance(error, subprocess.CalledProcessError):
        detail = "\n".join(
            text.strip() for text in (error.stdout, error.stderr) if text
        )
        message = (
            f"command failed with status {error.returncode}: {' '.join(error.cmd)}"
        )
        return message + (f": {detail}" if detail else "")
    return str(error)


def running_containers():
    command = [DOCKER, "ps", "--format", "{{.Names}}"]
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        raise RuntimeError(
            f"cannot list running containers: {describe(error)}"
        ) from error
    return set(result.stdout.splitlines())


def cleanup_stack(stack):
    subprocess.run(
        compose(stack, "down", "--timeout", STOP_TIMEOUT),
        capture_output=True,
        text=True,
        check=True,
    )
    container = f"llama-swap-{stack}"
    if container in running_containers():
        raise RuntimeError(f"container survived cleanup: {container}")


def terminate_group(process):
    for signum in (signal.SIGTERM, signal.SIGKILL):
        with suppress(ProcessLookupError):
            os.killpg(process.pid, signum)
        with suppress(subprocess.TimeoutExpired):
            process.wait(timeout=5)


def run_attached(command, env):
    if CANCEL_SIGNAL:
        raise Cancelled(CANCEL_SIGNAL)
    process = subprocess.Popen(command, env=env, start_new_session=True)
    while not CANCEL_SIGNAL:
        try:
            status = process.wait(timeout=0.1)
            break
        except subprocess.TimeoutExpired:
            pass
    terminate_group(process)
    if CANCEL_SIGNAL:
        raise Cancelled(CANCEL_SIGNAL)
    if status:
        raise subprocess.CalledProcessError(status, command)


def start(model, port):
    stack = STACKS[model]
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with (STATE_DIR / "ownership.lock").open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("another vLLM launcher owns the host lock") from error
        conflicts = CONTAINERS & running_containers()
        if conflicts:
            raise RuntimeError(f"container already running: {min(conflicts)}")
        env = os.environ | {"LLAMA_SWAP_PORT": str(port)}
        signal.signal(signal.SIGTERM, handle_signal)
        signal.signal(signal.SIGINT, handle_signal)
        try:
            run_attached(
                compose(stack, "up", "--exit-code-from", "fa2-init", "fa2-init"), env
            )
            run_attached(
                compose(stack, "up", "--exit-code-from", "vllm", "--no-deps", "vllm"),
                env,
            )
        finally:
            cleanup_stack(stack)


def handle_signal(signum, _frame):
    global CANCEL_SIGNAL
    CANCEL_SIGNAL = signum


def cleanup():
    errors = []
    for model, stack in STACKS.items():
        try:
            cleanup_stack(stack)
        except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
            errors.append(f"{model}: {describe(error)}")
    if errors:
        raise RuntimeError("; ".join(errors))


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    start_parser = commands.add_parser("start")
    start_parser.add_argument("model", choices=STACKS)
    start_parser.add_argument("port", type=port_number)
    stop_parser = commands.add_parser("stop")
    stop_parser.add_argument("model", choices=STACKS)
    commands.add_parser("cleanup")
    args = parser.parse_args()
    try:
        if args.command == "start":
            start(args.model, args.port)
        elif args.command == "stop":
            cleanup_stack(STACKS[args.model])
        else:
            cleanup()
        return 0
    except Cancelled as error:
        print(f"received signal {error.args[0]}", file=sys.stderr)
        return 128 + error.args[0]
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(describe(error), file=sys.stderr)
        return (
            error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        )


if __name__ == "__main__":
    raise SystemExit(main())
