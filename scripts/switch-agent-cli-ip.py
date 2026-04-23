#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "rich>=14.0.0",
# ]
# ///

from __future__ import annotations

import argparse
import socket
from pathlib import Path

from rich.console import Console
from rich.table import Table

HOME_IP = "192.168.1.5"
TAILSCALE_IP = "100.64.0.26"
PROBE_PORTS = (11434, 9292, 8880, 10302)
DEFAULT_CONFIG = Path.home() / ".config" / "agent-cli" / "config.toml"

console = Console()
stderr_console = Console(stderr=True)


def probe_host(host: str, timeout: float = 0.35) -> int | None:
    for port in PROBE_PORTS:
        try:
            with socket.create_connection((host, port), timeout=timeout):
                return port
        except OSError:
            continue
    return None


def choose_ip() -> tuple[str, dict[str, int | None]]:
    probe_results = {
        HOME_IP: probe_host(HOME_IP),
        TAILSCALE_IP: probe_host(TAILSCALE_IP),
    }

    # Prefer the local address when both are reachable.
    if probe_results[HOME_IP] is not None:
        return HOME_IP, probe_results
    if probe_results[TAILSCALE_IP] is not None:
        return TAILSCALE_IP, probe_results
    raise RuntimeError(
        f"Neither {HOME_IP} nor {TAILSCALE_IP} is reachable on ports {PROBE_PORTS}."
    )


def format_probe_status(host: str, port: int | None) -> str:
    if port is None:
        return "unreachable"
    return f"reachable on port {port}"


def render_probe_table(probe_results: dict[str, int | None]) -> None:
    table = Table(title="Reachability")
    table.add_column("IP", style="cyan")
    table.add_column("Status")

    for host in (HOME_IP, TAILSCALE_IP):
        port = probe_results[host]
        status = format_probe_status(host, port)
        if port is None:
            status = f"[red]{status}[/red]"
        else:
            status = f"[green]{status}[/green]"
        table.add_row(host, status)

    console.print(table)


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

    target_ip, probe_results = choose_ip()
    config_path = args.config.expanduser().resolve()
    original = config_path.read_text()
    updated = update_config(original, target_ip)

    console.print(f"[bold]Config:[/bold] {config_path}")
    render_probe_table(probe_results)
    console.print(f"[bold]Selected IP:[/bold] [green]{target_ip}[/green]")

    if original == updated:
        console.print(
            f"[yellow]{config_path} already uses {target_ip}[/yellow]"
        )
        return 0

    if args.dry_run:
        console.print(
            f"[yellow]Would switch {config_path} to {target_ip}[/yellow]"
        )
        return 0

    config_path.write_text(updated)
    console.print(f"[bold green]Switched {config_path} to {target_ip}[/bold green]")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        stderr_console.print(f"[bold red]{exc}[/bold red]")
        raise SystemExit(1)
