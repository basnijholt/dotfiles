#!/usr/bin/env python3

import argparse
import fcntl
import json
import os
import signal
import subprocess
import sys
from pathlib import Path


class LauncherError(Exception):
    pass


class Cancelled(Exception):
    def __init__(self, signum):
        self.signum = signum


def load_config(path):
    try:
        config = json.loads(Path(path).read_text())
        if not isinstance(config, dict):
            raise TypeError("top level must be an object")
        required_strings = ("cf", "cfConfig", "docker", "stateDir")
        if not all(isinstance(config.get(key), str) for key in required_strings):
            raise TypeError("paths must be strings")
        if type(config.get("stopTimeout")) is not int:
            raise TypeError("stopTimeout must be an integer")
        if config["stopTimeout"] < 0:
            raise ValueError("stopTimeout must not be negative")
        legacy_containers = config.get("legacyContainers")
        if not isinstance(legacy_containers, list) or not all(
            isinstance(name, str) for name in legacy_containers
        ):
            raise TypeError("legacyContainers must be a list of strings")
        models = config.get("models")
        if not isinstance(models, dict) or not models:
            raise ValueError("models must be a non-empty object")
        for model in models.values():
            if not isinstance(model, dict) or not all(
                isinstance(model.get(key), str)
                for key in ("stack", "service", "container")
            ):
                raise TypeError("each model requires stack, service, and container")
    except (OSError, json.JSONDecodeError, TypeError, ValueError) as error:
        raise LauncherError(f"invalid config {path}: {error}") from error
    return config


def model_config(config, name):
    try:
        return config["models"][name]
    except KeyError as error:
        raise LauncherError(f"unknown model: {name}") from error


def port_number(value):
    try:
        port = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("port must be an integer") from error
    if not 1024 <= port <= 65535:
        raise argparse.ArgumentTypeError("port must be in 1024..65535")
    return port


def inspect_container(config, container):
    command = [
        config["docker"],
        "inspect",
        "--format",
        "{{.State.Running}}",
        container,
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as error:
        raise LauncherError(f"cannot inspect container {container}: {error}") from error

    output = result.stdout.strip().lower()
    if result.returncode == 0 and output in ("true", "false"):
        return output == "true"
    diagnostic = "\n".join(
        part.strip() for part in (result.stdout, result.stderr) if part
    )
    if result.returncode == 1 and (
        "No such object:" in diagnostic or "No such container:" in diagnostic
    ):
        return False
    raise LauncherError(
        f"cannot determine container state for {container}"
        + (f": {diagnostic}" if diagnostic else "")
    )


def compose_command(config, model, command, *args):
    return [
        config["cf"],
        "compose",
        "--config",
        config["cfConfig"],
        model["stack"],
        command,
        *args,
    ]


def command_failure(command, result):
    diagnostic = "\n".join(
        part.strip() for part in (result.stdout, result.stderr) if part
    )
    message = f"command failed with status {result.returncode}: {' '.join(command)}"
    return message + (f": {diagnostic}" if diagnostic else "")


def cleanup_model(config, model):
    command = compose_command(
        config, model, "down", "--timeout", str(config["stopTimeout"])
    )
    errors = []
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            errors.append(command_failure(command, result))
    except OSError as error:
        errors.append(f"cannot run cleanup command: {error}")

    try:
        if inspect_container(config, model["container"]):
            errors.append(f"container survived cleanup: {model['container']}")
    except LauncherError as error:
        errors.append(str(error))
    return errors


def terminate_process_group(process, timeout):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=max(0.1, min(5, timeout)))
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    if process.poll() is None:
        process.wait()


def run_cancelable(command, cancel, env, timeout):
    if cancel["signum"] is not None:
        raise Cancelled(cancel["signum"])
    try:
        process = subprocess.Popen(command, env=env, start_new_session=True)
    except OSError as error:
        raise LauncherError(f"cannot start {' '.join(command)}: {error}") from error

    while True:
        if cancel["signum"] is not None:
            terminate_process_group(process, timeout)
            raise Cancelled(cancel["signum"])
        try:
            return process.wait(timeout=0.1)
        except subprocess.TimeoutExpired:
            continue


def reject_conflicts(config):
    containers = [model["container"] for model in config["models"].values()]
    containers.extend(config.get("legacyContainers", []))
    for container in containers:
        if inspect_container(config, container):
            raise LauncherError(f"conflicting container is running: {container}")


def start(config, name, port):
    model = model_config(config, name)
    state_dir = Path(config["stateDir"])
    state_dir.mkdir(parents=True, exist_ok=True)
    lock_path = state_dir / "ownership.lock"

    with lock_path.open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise LauncherError("another vLLM launcher owns the host lock") from error

        reject_conflicts(config)
        cancel = {"signum": None}

        def handle_signal(signum, _frame):
            cancel["signum"] = signum

        previous = {
            signum: signal.signal(signum, handle_signal)
            for signum in (signal.SIGTERM, signal.SIGINT)
        }
        attempted_start = False
        failure = None
        exit_code = 0
        try:
            env = os.environ.copy()
            env["LLAMA_SWAP_PORT"] = str(port)
            attempted_start = True
            up = compose_command(config, model, "up", "-d", model["service"])
            if run_cancelable(up, cancel, env, config["stopTimeout"]) != 0:
                raise LauncherError(f"failed to start model {name}")
            if not inspect_container(config, model["container"]):
                raise LauncherError(
                    f"container is not running after start: {model['container']}"
                )
            wait = [config["docker"], "wait", model["container"]]
            if (
                run_cancelable(wait, cancel, os.environ.copy(), config["stopTimeout"])
                != 0
            ):
                raise LauncherError(f"failed while waiting for model {name}")
        except Cancelled as error:
            failure = f"received signal {error.signum}"
            exit_code = 128 + error.signum
        except LauncherError as error:
            failure = str(error)
            exit_code = 1
        finally:
            cleanup_errors = cleanup_model(config, model) if attempted_start else []
            for signum, handler in previous.items():
                signal.signal(signum, handler)

        if failure:
            print(failure, file=sys.stderr)
        if cleanup_errors:
            print("; ".join(cleanup_errors), file=sys.stderr)
            return 1
        return exit_code


def stop(config, name):
    errors = cleanup_model(config, model_config(config, name))
    if errors:
        raise LauncherError("; ".join(errors))
    return 0


def cleanup(config):
    errors = []
    for name, model in config["models"].items():
        errors.extend(f"{name}: {error}" for error in cleanup_model(config, model))
    if errors:
        raise LauncherError("; ".join(errors))
    return 0


def parse_args(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    commands = parser.add_subparsers(dest="command", required=True)
    start_parser = commands.add_parser("start")
    start_parser.add_argument("model")
    start_parser.add_argument("port", type=port_number)
    stop_parser = commands.add_parser("stop")
    stop_parser.add_argument("model")
    commands.add_parser("cleanup")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        config = load_config(args.config)
        if args.command == "start":
            return start(config, args.model, args.port)
        if args.command == "stop":
            return stop(config, args.model)
        return cleanup(config)
    except LauncherError as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
