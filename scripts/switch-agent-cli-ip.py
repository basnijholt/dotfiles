#!/usr/bin/env -S uv run --script

from __future__ import annotations

import argparse
import socket
import sys
from pathlib import Path

HOME_IP = "192.168.1.5"
TAILSCALE_IP = "100.64.0.26"
PROBE_PORTS = (11434, 9292, 8880, 10302)
DEFAULT_CONFIG = Path.home() / ".config" / "agent-cli" / "config.toml"


def is_reachable(host: str, timeout: float = 0.35) -> bool:
    for port in PROBE_PORTS:
        try:
            with socket.create_connection((host, port), timeout=timeout):
                return True
        except OSError:
            continue
    return False


def choose_ip() -> str:
    # Prefer the local address when both are reachable.
    if is_reachable(HOME_IP):
        return HOME_IP
    if is_reachable(TAILSCALE_IP):
        return TAILSCALE_IP
    raise RuntimeError(
        f"Neither {HOME_IP} nor {TAILSCALE_IP} is reachable on ports {PROBE_PORTS}."
    )


def update_config(text: str, target_ip: str) -> str:
    lines: list[str] = []
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith("#"):
            lines.append(line)
            continue
        line = line.replace(HOME_IP, target_ip)
        line = line.replace(TAILSCALE_IP, target_ip)
        lines.append(line)
    return "".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    target_ip = choose_ip()
    config_path = args.config.expanduser().resolve()
    original = config_path.read_text()
    updated = update_config(original, target_ip)

    if original == updated:
        print(f"{config_path} already uses {target_ip}")
        return 0

    if args.dry_run:
        print(f"Would switch {config_path} to {target_ip}")
        return 0

    config_path.write_text(updated)
    print(f"Switched {config_path} to {target_ip}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(exc, file=sys.stderr)
        raise SystemExit(1)
