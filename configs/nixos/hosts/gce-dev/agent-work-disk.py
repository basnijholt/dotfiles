#!/usr/bin/env python3
"""Encrypted disk for coding-agent credentials and data.

The disk is never unlocked at boot: `agent-work-disk unlock` asks for the
passphrase, mounts it and points the agents' directories in $HOME at it.
While it is mounted, `agent-work-disk guard` (a systemd unit) locks it again
the moment anyone else logs in: a session for another user, a password
login, or an SSH key that is not one of the NixOS-managed keys.

Settings (device, mount point, links) come from /etc/agent-work-disk.json,
written by agent-work-disk.nix; agent-work-disk-guard-test points
AGENT_WORK_DISK_CONFIG at a throwaway disk instead.
"""

from __future__ import annotations

import argparse
import json
import os
import pwd
import re
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

CONFIG = Path(os.environ.get("AGENT_WORK_DISK_CONFIG", "/etc/agent-work-disk.json"))
TAG = "agent-work-disk"
SSHD_LOGS = ["SYSLOG_IDENTIFIER=sshd", "SYSLOG_IDENTIFIER=sshd-session", "SYSLOG_IDENTIFIER=sshd-auth"]
os.environ["PATH"] = "/run/wrappers/bin:/run/current-system/sw/bin:" + os.environ.get("PATH", "")

KEY_LOGIN = re.compile(r"^Accepted publickey for (\S+) from .* (SHA256:\S+)$")
OTHER_LOGIN = re.compile(r"^Accepted (\S+) for (\S+)")
NEW_SESSION = re.compile(r"^New session '?[^ ']+'? of user '?([^ ']+)'?[ .]")


def run(cmd: list, *, check: bool = True, quiet: bool = False, **kwargs) -> subprocess.CompletedProcess:
    if quiet:
        kwargs.setdefault("stdout", subprocess.DEVNULL)
        kwargs.setdefault("stderr", subprocess.DEVNULL)
    return subprocess.run([str(c) for c in cmd], check=check, **kwargs)


def output(cmd: list) -> str:
    return run(cmd, capture_output=True, text=True).stdout


def sudo(cmd: list, **kwargs) -> subprocess.CompletedProcess:
    return run(([] if os.geteuid() == 0 else ["sudo"]) + cmd, **kwargs)


def active(unit: str) -> bool:
    return run(["systemctl", "is-active", "-q", unit], check=False).returncode == 0


def log(priority: str, message: str) -> None:
    run(["logger", "-p", f"auth.{priority}", "-t", TAG, message], check=False)


def mapping(name: str) -> Path:
    return Path("/dev/mapper") / name


def suspended(name: str) -> bool:
    dm = Path(os.path.realpath(mapping(name))).name
    return Path(f"/sys/block/{dm}/dm/suspended").read_text().strip() == "1"


def link(cfg: dict) -> None:
    """Point the configured $HOME paths at the disk, moving real ones over once.

    Anything written while a link was missing (say, before the first unlock)
    is a real file or directory in $HOME; it moves to the disk, unless the
    disk already has that entry, in which case both stay for a manual merge.
    """
    home, root = Path.home(), Path(cfg["mountPoint"]) / "config"
    for kind in ("dirLinks", "fileLinks"):
        for name, target in cfg[kind].items():
            src, dst = home / name, root / target
            if src.exists() and not src.is_symlink():
                if dst.exists() or dst.is_symlink():
                    print(f"warning: {src} and {dst} both exist; merge them by hand", file=sys.stderr)
                    continue
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(src, dst)
                print(f"moved {src} to {dst}")
            # A dangling directory link breaks the tools' own mkdir -p.
            if kind == "dirLinks":
                dst.mkdir(parents=True, exist_ok=True)
            src.parent.mkdir(parents=True, exist_ok=True)
            if src.is_symlink():
                if os.readlink(src) == str(dst):
                    continue
                src.unlink()
            src.symlink_to(dst)


def unlock(cfg: dict) -> int:
    if os.geteuid() == 0:
        sys.exit("run unlock as yourself; it uses sudo where needed")
    mount, mapper, unit = cfg["mountPoint"], cfg["mapper"], cfg["guardUnit"]
    if not os.path.ismount(mount):
        if not mapping(mapper).exists():
            sudo(["cryptsetup", "open", cfg["device"], mapper])
        elif suspended(mapper):
            # Left behind by a lock that could not close the mapping.
            sudo(["cryptsetup", "luksResume", mapper])
        # Arm as soon as the key is in kernel memory. The guard first checks
        # the logins that are already open, and only then reports ready.
        started = sudo(["systemctl", "start", unit], check=False).returncode == 0
        if not started or not mapping(mapper).exists() or suspended(mapper):
            if mapping(mapper).exists() and not suspended(mapper):
                sudo(["cryptsetup", "close", mapper], check=False)
            sys.exit(f"the guard locked the disk again; see `journalctl -t {TAG} -u {unit}`")
        sudo(["mount", mount])
    sudo(["systemctl", "start", unit])
    if not os.path.ismount(mount):
        sys.exit(f"{mount} is not mounted; nothing changed on the plain disk")
    # The disk's root belongs to the user (the empty mount point below it
    # stays root's).
    user = pwd.getpwnam(cfg["user"])
    sudo(["install", "-d", "-o", user.pw_uid, "-g", user.pw_gid, "-m", "0755", mount])
    sudo(["install", "-d", "-o", user.pw_uid, "-g", user.pw_gid, "-m", "0700", f"{mount}/config"])
    link(cfg)
    print(f"{mount} unlocked, guard armed")
    return 0


def lock(cfg: dict) -> int:
    mount, mapper = cfg["mountPoint"], cfg["mapper"]
    # Disarm last, so a failed umount (something still uses the disk) leaves
    # the guard on.
    if os.path.ismount(mount):
        if sudo(["umount", mount], check=False).returncode != 0:
            print(f"{mount} is busy; see `fuser -vm {mount}`", file=sys.stderr)
            return 1
    if mapping(mapper).exists():
        sudo(["cryptsetup", "close", mapper])
    sudo(["systemctl", "stop", cfg["guardUnit"]])
    print(f"{mount} locked")
    return 0


def status(cfg: dict) -> int:
    mount, mapper = cfg["mountPoint"], cfg["mapper"]
    state = "closed" if not mapping(mapper).exists() else "suspended" if suspended(mapper) else "open"
    print(f"{mount}: {'unlocked' if os.path.ismount(mount) else 'locked'}")
    print(f"mapping {mapper}: {state}")
    print(f"guard: {'armed' if active(cfg['guardUnit']) else 'off'}")
    return 0


def foreign_login(line: str, user: str, keys: set[str]) -> str | None:
    """Why a journal line is a login by someone else, or None if it is not."""
    if m := KEY_LOGIN.match(line):
        return None if m[2] in keys else f"unknown key {m[2]} for {m[1]}"
    if m := OTHER_LOGIN.match(line):
        return f"{m[1]} login for {m[2]}"
    if m := NEW_SESSION.match(line):
        return None if m[1] == user else f"session for {m[1]}"
    return None


def open_logins(user: str, keys: set[str]) -> list[str]:
    """Why sessions that are open right now belong to someone else.

    logind lists every session that still has processes, even after its
    leader exited. An SSH session's leader is the sshd-session process that
    logged the session's "Accepted ..." line.
    """
    accepted = {}
    for entry in map(json.loads, output(["journalctl", "--boot", "--output=json", *SSHD_LOGS]).splitlines()):
        message = entry.get("MESSAGE")
        if isinstance(message, str) and message.startswith("Accepted "):
            accepted[entry.get("_PID")] = message  # the latest wins if a PID was reused
    reasons = []
    for session in json.loads(output(["loginctl", "list-sessions", "--json=short"])):
        if session["user"] != user:
            reasons.append(f"open session for {session['user']}")
        elif reason := foreign_login(accepted.get(str(session.get("leader")), ""), user, keys):
            reasons.append(f"open session: {reason}")
    return reasons


def notify_ready() -> None:
    """Tell systemd (Type=notify) the guard is watching; `systemctl start` waits for this."""
    if address := os.environ.get("NOTIFY_SOCKET"):
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as s:
            s.connect("\0" + address[1:] if address.startswith("@") else address)
            s.sendall(b"READY=1")


def lock_now(mount: str, mapper: str, reason: str) -> None:
    log("alert", f"locking {mount}: {reason}")
    for _ in range(3):
        if not os.path.ismount(mount):
            break
        # With -M, fuser does nothing unless the path really is a mount point,
        # so it can never kill everything on the root filesystem.
        run(["fuser", "-kmM", mount], check=False, quiet=True)
        time.sleep(0.5)
        if run(["umount", mount], check=False, quiet=True).returncode == 0:
            break
    if os.path.ismount(mount):
        run(["umount", "-l", mount], check=False)
    # After a lazy unmount the mapping can stay busy and refuse to close;
    # luksSuspend then at least drops the key from kernel memory.
    if mapping(mapper).exists() and run(["cryptsetup", "close", mapper], check=False).returncode != 0:
        run(["cryptsetup", "luksSuspend", mapper], check=False)
    log("alert", f"locked {mount}")


def guard(cfg: dict) -> int:
    user = cfg["user"]
    listing = run(["ssh-keygen", "-lf", cfg["keysFile"]], check=False, capture_output=True, text=True).stdout
    keys = {fields[1] for fields in map(str.split, listing.splitlines()) if len(fields) > 1}
    if not keys:
        log("err", f"no keys in {cfg['keysFile']}")
        return 1
    # Follow from the start of this second, then check the sessions that are
    # already open: together they cover logins during startup too. sshd
    # reports the key behind every login; logind reports every session,
    # including ones that bypass sshd.
    journal = subprocess.Popen(
        ["journalctl", "--follow", f"--since=@{int(time.time())}", "--lines=all", "--output=cat",
         "_SYSTEMD_UNIT=systemd-logind.service", "+", *SSHD_LOGS],
        stdout=subprocess.PIPE, text=True,
    )
    assert journal.stdout is not None
    reason = "; ".join(open_logins(user, keys))
    if not reason:
        notify_ready()
        for line in journal.stdout:
            if reason := foreign_login(line.rstrip("\n"), user, keys):
                break
        else:
            # Fail, so systemd restarts the guard.
            log("err", "journal stream ended")
            return 1
    journal.kill()
    lock_now(cfg["mountPoint"], cfg["mapper"], reason)
    # After a lock at startup this is the first READY: `systemctl start`
    # returns and `unlock` finds the disk closed. Exiting without it would
    # count as a failed start and make systemd retry.
    notify_ready()
    return 0


COMMANDS = {
    "unlock": (unlock, "ask for the passphrase, mount, arm the guard, link the agent dirs"),
    "lock": (lock, "unmount and close the disk, then disarm the guard"),
    "status": (status, "show whether the disk is unlocked and the guard armed"),
    "guard": (guard, "lock the disk on a foreign login (run by systemd)"),
}


def main() -> int:
    parser = argparse.ArgumentParser(prog="agent-work-disk", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name, (_, help_text) in COMMANDS.items():
        sub.add_parser(name, help=help_text)
    args = parser.parse_args()
    try:
        return COMMANDS[args.command][0](json.loads(CONFIG.read_text()))
    except subprocess.CalledProcessError as e:
        print(f"agent-work-disk: `{' '.join(map(str, e.cmd))}` failed (exit {e.returncode})", file=sys.stderr)
        return e.returncode or 1


if __name__ == "__main__":
    sys.exit(main())
