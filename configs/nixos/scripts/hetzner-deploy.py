#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer", "rich", "python-dotenv"]
# ///
"""Deploy NixOS to Hetzner Cloud using nixos-anywhere."""

import os
import subprocess
import time
from pathlib import Path

import typer
from dotenv import load_dotenv
from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn

app = typer.Typer(
    help="Deploy NixOS to Hetzner Cloud",
    no_args_is_help=True,
    context_settings={"help_option_names": ["-h", "--help"]},
)
console = Console()

SCRIPT_DIR = Path(__file__).parent
FLAKE_DIR = SCRIPT_DIR.parent
ENV_FILE = FLAKE_DIR / ".env"

# Load environment variables from .env file
if ENV_FILE.exists():
    load_dotenv(ENV_FILE)
    console.print(f"[dim]Loaded environment from {ENV_FILE}[/dim]")
else:
    console.print(f"[yellow]Warning: {ENV_FILE} not found[/yellow]")


def run(cmd: list[str], check: bool = True, capture: bool = False) -> subprocess.CompletedProcess:
    """Run a command."""
    result = subprocess.run(cmd, capture_output=capture, text=True)
    if check and result.returncode != 0:
        console.print(f"[red]Command failed:[/red] {' '.join(cmd)}")
        if result.stderr:
            console.print(f"[red]{result.stderr}[/red]")
        raise typer.Exit(1)
    return result


def hcloud(*args: str, capture: bool = False, check: bool = True) -> subprocess.CompletedProcess:
    """Run hcloud command."""
    return run(["hcloud", *args], capture=capture, check=check)


def ssh_check(ip: str) -> bool:
    """Check if SSH is available."""
    result = subprocess.run(
        ["ssh", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no",
         "-o", "UserKnownHostsFile=/dev/null", f"root@{ip}", "true"],
        capture_output=True,
    )
    return result.returncode == 0


def wait_for_ssh(ip: str, timeout: int = 120) -> None:
    """Wait for SSH to become available."""
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task(f"[cyan]Waiting for SSH on {ip}...", total=None)
        start = time.time()
        while time.time() - start < timeout:
            if ssh_check(ip):
                progress.update(task, description="[green]SSH ready!")
                return
            time.sleep(2)
        console.print("[red]Timeout waiting for SSH[/red]")
        raise typer.Exit(1)


@app.command()
def deploy(
    name: str = typer.Argument("hetzner", help="Server name"),
    server_type: str = typer.Option("cax11", "--type", "-t", help="Server type (cax11=ARM €3.29/mo)"),
    location: str = typer.Option("fsn1", "--location", "-l", help="Datacenter location"),
    delete_existing: bool = typer.Option(False, "--delete", "-d", help="Delete existing server"),
):
    """Deploy NixOS to a new Hetzner Cloud server."""
    # Check prerequisites
    token = os.environ.get("HCLOUD_TOKEN")
    if not token:
        console.print("[red]HCLOUD_TOKEN environment variable not set[/red]")
        raise typer.Exit(1)

    console.print(Panel.fit(
        f"[bold]Deploying NixOS to Hetzner Cloud[/bold]\n"
        f"Server: [cyan]{name}[/cyan] | Type: [cyan]{server_type}[/cyan] | Location: [cyan]{location}[/cyan]",
        border_style="blue",
    ))

    # Check if server exists
    result = hcloud("server", "describe", name, capture=True, check=False)
    if result.returncode == 0:
        if delete_existing:
            console.print(f"[yellow]Deleting existing server '{name}'...[/yellow]")
            hcloud("server", "delete", name)
            time.sleep(3)
        else:
            console.print(f"[red]Server '{name}' already exists. Use --delete to recreate.[/red]")
            raise typer.Exit(1)

    # Get or create SSH key
    ssh_key_name = "nixos-deploy"
    result = hcloud("ssh-key", "describe", ssh_key_name, capture=True, check=False)
    if result.returncode != 0:
        console.print("[cyan]Creating SSH key in Hetzner...[/cyan]")
        for key_file in ["~/.ssh/id_ed25519.pub", "~/.ssh/id_rsa.pub"]:
            key_path = Path(key_file).expanduser()
            if key_path.exists():
                hcloud("ssh-key", "create", "--name", ssh_key_name, "--public-key-from-file", str(key_path))
                break
        else:
            console.print("[red]No SSH public key found in ~/.ssh/[/red]")
            raise typer.Exit(1)

    # Create server
    console.print(f"[cyan]Creating server '{name}'...[/cyan]")
    hcloud(
        "server", "create",
        "--name", name,
        "--type", server_type,
        "--image", "ubuntu-24.04",
        "--location", location,
        "--ssh-key", ssh_key_name,
    )

    # Get server IP
    result = hcloud("server", "ip", name, capture=True)
    server_ip = result.stdout.strip()
    console.print(f"[green]Server created:[/green] {server_ip}")

    # Wait for initial SSH
    wait_for_ssh(server_ip)

    # Enable rescue mode
    console.print("[cyan]Enabling rescue mode...[/cyan]")
    hcloud("server", "enable-rescue", "--ssh-key", ssh_key_name, name)
    hcloud("server", "reset", name)

    # Wait for rescue mode (ARM takes longer to boot)
    time.sleep(30)
    wait_for_ssh(server_ip, timeout=180)

    # Run nixos-anywhere
    console.print("[cyan]Running nixos-anywhere...[/cyan]")
    flake_ref = f"{FLAKE_DIR}#{name}"
    run([
        "nix", "run", "github:nix-community/nixos-anywhere", "--",
        "--flake", flake_ref,
        "--target-host", f"root@{server_ip}",
        "--build-on-remote",
    ])

    console.print(Panel.fit(
        f"[bold green]Deployment complete![/bold green]\n\n"
        f"IP: [cyan]{server_ip}[/cyan]\n"
        f"SSH: [cyan]ssh basnijholt@{server_ip}[/cyan]",
        border_style="green",
    ))


@app.command()
def destroy(
    name: str = typer.Argument("hetzner", help="Server name to delete"),
    force: bool = typer.Option(False, "--force", "-f", help="Skip confirmation"),
):
    """Delete a Hetzner Cloud server."""
    result = hcloud("server", "describe", name, capture=True, check=False)
    if result.returncode != 0:
        console.print(f"[yellow]Server '{name}' not found[/yellow]")
        raise typer.Exit(0)

    if not force:
        confirm = typer.confirm(f"Delete server '{name}'?", default=False)
        if not confirm:
            console.print("[dim]Aborted[/dim]")
            raise typer.Exit(0)

    console.print(f"[yellow]Deleting server '{name}'...[/yellow]")
    hcloud("server", "delete", name)
    console.print(f"[green]Server '{name}' deleted[/green]")


@app.command()
def status(name: str = typer.Argument("hetzner", help="Server name")):
    """Show server status."""
    hcloud("server", "describe", name)


if __name__ == "__main__":
    app()
