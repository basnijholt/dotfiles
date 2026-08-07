#!/usr/bin/env python3
"""Install and operate a NixOS coding-agent box through GCP IAP."""

from __future__ import annotations

import argparse
import shlex
import subprocess
from pathlib import Path

DEFAULT_ZONE = "us-east1-c"
DEFAULT_INSTANCE = "agent-box"
# Resolved over the network, so local edits need pushing first.
FLAKE_REF = "github:basnijholt/dotfiles?dir=configs/nixos#gce-agent-box"


def run(
    command: list[str], *, capture: bool = False
) -> subprocess.CompletedProcess[str]:
    print("+", shlex.join(command))
    return subprocess.run(command, check=True, text=True, capture_output=capture)


def iap_proxy_command(project: str, zone: str, instance: str) -> str:
    return (
        f"gcloud compute start-iap-tunnel {instance} 22 "
        f"--listen-on-stdin --project {project} --zone {zone} --verbosity=warning"
    )


def nixos_anywhere_command(
    project: str,
    zone: str,
    instance: str,
    ssh_user: str,
    identity_file: Path,
    flake: str,
    build_on_remote: bool,
) -> list[str]:
    return [
        "nix",
        "run",
        "github:nix-community/nixos-anywhere",
        "--",
        "--flake",
        flake,
        *(["--build-on-remote"] if build_on_remote else []),
        "--target-host",
        f"{ssh_user}@{instance}",
        "--ssh-option",
        f"IdentityFile={identity_file}",
        "--ssh-option",
        f"ProxyCommand={iap_proxy_command(project, zone, instance)}",
        "--ssh-option",
        "StrictHostKeyChecking=no",
        "--ssh-option",
        "UserKnownHostsFile=/dev/null",
    ]


def ssh_command(
    project: str,
    zone: str,
    instance: str,
    ssh_user: str,
    identity_file: Path,
    remote_command: str | None = None,
    tty: bool = False,
) -> list[str]:
    command = [
        "ssh",
        "-i",
        str(identity_file),
        "-o",
        f"ProxyCommand={iap_proxy_command(project, zone, instance)}",
        "-o",
        "StrictHostKeyChecking=accept-new",
    ]
    if tty:
        command.append("-t")
    command.append(f"{ssh_user}@{instance}")
    if remote_command is not None:
        command.append(remote_command)
    return command


def unlock_work_command(
    project: str,
    zone: str,
    instance: str,
    ssh_user: str,
    identity_file: Path,
) -> list[str]:
    return ssh_command(
        project,
        zone,
        instance,
        ssh_user,
        identity_file,
        remote_command="sudo agent-work-disk unlock",
        tty=True,
    )


def deploy(
    project: str,
    zone: str,
    instance: str,
    ssh_user: str,
    identity_file: Path,
    flake: str,
    build_on_remote: bool,
) -> None:
    if not identity_file.exists():
        raise FileNotFoundError(f"SSH identity file does not exist: {identity_file}")
    run(
        nixos_anywhere_command(
            project=project,
            zone=zone,
            instance=instance,
            ssh_user=ssh_user,
            identity_file=identity_file,
            flake=flake,
            build_on_remote=build_on_remote,
        )
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True)
    parser.add_argument("--zone", default=DEFAULT_ZONE)
    parser.add_argument("--instance", default=DEFAULT_INSTANCE)
    parser.add_argument("--ssh-user", default="basnijholt")
    parser.add_argument(
        "--identity-file",
        type=Path,
        default=Path("~/.ssh/id_ed25519").expanduser(),
    )
    parser.add_argument(
        "--flake",
        default=FLAKE_REF,
        help="Flake reference to install.",
    )
    parser.add_argument(
        "--build-on-remote",
        action="store_true",
        help="Build on the target instead of locally.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("deploy", help="Install NixOS through IAP")
    subparsers.add_parser("ssh", help="Open an interactive IAP SSH session")
    subparsers.add_parser(
        "unlock-work",
        help="Interactively initialize or unlock the encrypted /work disk",
    )
    subparsers.add_parser("status", help="Show GCE instance status")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "deploy":
        deploy(
            args.project,
            args.zone,
            args.instance,
            args.ssh_user,
            args.identity_file,
            args.flake,
            args.build_on_remote,
        )
    elif args.command == "ssh":
        run(
            ssh_command(
                args.project,
                args.zone,
                args.instance,
                args.ssh_user,
                args.identity_file,
            )
        )
    elif args.command == "unlock-work":
        run(
            unlock_work_command(
                args.project,
                args.zone,
                args.instance,
                args.ssh_user,
                args.identity_file,
            )
        )
    else:
        run(
            [
                "gcloud",
                "compute",
                "instances",
                "describe",
                args.instance,
                f"--project={args.project}",
                f"--zone={args.zone}",
            ]
        )


if __name__ == "__main__":
    main()
