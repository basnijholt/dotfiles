#!/usr/bin/env python3
"""End-to-end test of `agent-work-disk guard` on a throwaway LUKS disk.

Run as `sudo agent-work-disk-guard-test --pause-guard`. It formats a small
file-backed LUKS disk, runs the guard on it as a transient unit and makes
real logins: the user's own session and an SSH login with a trusted key
must be ignored; an SSH login with an unknown key, a session for nobody and
an unknown-key login that was already open when the guard started must
lock the disk. The real disk is never touched, but those test logins would
lock it too, so the real guard is paused for the test.
"""

from __future__ import annotations

import argparse
import json
import os
import pwd
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

CONFIG = Path("/etc/agent-work-disk.json")
GUARD = Path(__file__).resolve().parent / "agent-work-disk"
UNIT = "agent-work-disk-guard-test"
MAPPER = "agent-work-disk-test"
MOUNT = Path("/run/agent-work-disk-test")
os.environ["PATH"] = "/run/wrappers/bin:/run/current-system/sw/bin:" + os.environ.get("PATH", "")


def run(cmd: list, *, check: bool = True, quiet: bool = False) -> subprocess.CompletedProcess:
    out = subprocess.DEVNULL if quiet else None
    return subprocess.run([str(c) for c in cmd], check=check, stdout=out, stderr=out)


def output(cmd: list) -> str:
    return subprocess.run([str(c) for c in cmd], capture_output=True, text=True).stdout


def active(unit: str) -> bool:
    return run(["systemctl", "is-active", "-q", unit], check=False).returncode == 0


def mapped() -> bool:
    return (Path("/dev/mapper") / MAPPER).exists()


class GuardTest:
    def __init__(self, cfg: dict, user: str) -> None:
        pw = pwd.getpwnam(user)
        self.cfg, self.user, self.uid, self.gid = cfg, user, pw.pw_uid, pw.pw_gid
        self.keys = Path(pw.pw_dir) / ".ssh" / "authorized_keys"
        self.tmp = Path(tempfile.mkdtemp())
        self.tmp.chmod(0o711)  # the user's ssh-keygen writes below it
        self.marker = f"{UNIT}-{os.getpid()}"
        self.made_ssh_dir = self.made_keys = self.failed = False
        self.holder: subprocess.Popen | None = None
        self.bystander: subprocess.Popen | None = None
        self.held: subprocess.Popen | None = None
        self.sessions: set[str] = set()
        self.since = 0

    def check(self, ok: bool, label: str) -> None:
        print(f"{'PASS' if ok else 'FAIL'}  {label}", flush=True)
        self.failed |= not ok

    def setup(self) -> None:
        disk, key = self.tmp / "disk", self.tmp / "key"
        with open(disk, "wb") as f:
            f.truncate(64 << 20)
        key.write_bytes(os.urandom(64))
        run(["cryptsetup", "luksFormat", "-q", "--type", "luks2", "--pbkdf", "pbkdf2",
             "--pbkdf-force-iterations", "1000", "--key-file", key, disk])
        run(["cryptsetup", "open", "--key-file", key, disk, MAPPER])
        run(["mkfs.ext4", "-q", f"/dev/mapper/{MAPPER}"])
        run(["cryptsetup", "close", MAPPER])
        MOUNT.mkdir(exist_ok=True)

        # A key sshd accepts via ~/.ssh/authorized_keys, but that is not in
        # the NixOS-managed list the guard trusts.
        ssh = self.tmp / "ssh"
        ssh.mkdir(mode=0o700)
        os.chown(ssh, self.uid, self.gid)
        run(["runuser", "-u", self.user, "--", "ssh-keygen", "-q", "-t", "ed25519", "-N", "",
             "-C", self.marker, "-f", ssh / "id"])
        if not self.keys.parent.exists():
            self.keys.parent.mkdir(mode=0o700)
            os.chown(self.keys.parent, self.uid, self.gid)
            self.made_ssh_dir = True
        if not self.keys.exists():
            self.keys.touch(mode=0o600)
            os.chown(self.keys, self.uid, self.gid)
            self.made_keys = True
        pub = (ssh / "id.pub").read_text()
        existing = self.keys.read_text()
        with self.keys.open("a") as f:
            f.write(("\n" if existing and not existing.endswith("\n") else "") + pub)
        trusted = Path(self.cfg["keysFile"]).read_text().rstrip("\n")
        (self.tmp / "trusted.pub").write_text(f"{trusted}\n{pub}")

    def cleanup(self) -> None:
        run(["systemctl", "stop", UNIT], check=False, quiet=True)
        self.stop_helpers()
        self.close_sessions()
        if os.path.ismount(MOUNT):
            run(["umount", "-l", MOUNT], check=False)
        if mapped():
            run(["cryptsetup", "luksResume", "--key-file", self.tmp / "key", MAPPER], check=False, quiet=True)
            run(["cryptsetup", "close", MAPPER], check=False)
        if self.made_ssh_dir:
            shutil.rmtree(self.keys.parent, ignore_errors=True)
        elif self.made_keys:
            self.keys.unlink(missing_ok=True)
        elif self.keys.exists():
            kept = [line for line in self.keys.read_text().splitlines(keepends=True) if self.marker not in line]
            # Truncate and write the same inode: owner and permissions stay intact.
            with self.keys.open("w") as f:
                f.write("".join(kept))
        shutil.rmtree(self.tmp, ignore_errors=True)
        try:
            MOUNT.rmdir()
        except OSError:
            pass

    def mount_disk(self) -> None:
        run(["cryptsetup", "open", "--key-file", self.tmp / "key", self.tmp / "disk", MAPPER])
        run(["mount", f"/dev/mapper/{MAPPER}", MOUNT])
        self.holder = subprocess.Popen(["tail", "-f", "/dev/null"], cwd=MOUNT)
        self.bystander = subprocess.Popen(["tail", "-f", "/dev/null"])

    def stop_helpers(self) -> None:
        for proc in (self.holder, self.bystander):
            if proc:
                proc.kill()
                proc.wait()
        self.holder = self.bystander = None

    def open_sessions(self) -> list[str]:
        """The test's sessions that logind still lists."""
        listed = json.loads(output(["loginctl", "list-sessions", "--json=short"]) or "[]")
        return [s["session"] for s in listed if s["session"] in self.sessions or s["user"] == "nobody"]

    def close_sessions(self) -> None:
        """End the test's sessions and wait for them: a guard started later would lock on them."""
        for session in self.sessions:
            run(["loginctl", "terminate-session", session], check=False, quiet=True)
        if self.held:
            self.held.kill()
            self.held.wait()
            self.held = None
        for _ in range(100):
            if not self.open_sessions():
                return
            time.sleep(0.1)
        print(f"warning: test sessions still open: {' '.join(self.open_sessions())}", flush=True)

    def start_guard(self, keys_file: Path | None = None) -> None:
        """(Re)start the guard on the throwaway disk; it trusts `keys_file`."""
        run(["systemctl", "stop", UNIT], check=False, quiet=True)
        config = self.tmp / "config.json"
        config.write_text(json.dumps({**self.cfg, "mountPoint": str(MOUNT), "mapper": MAPPER,
                                      "keysFile": str(keys_file or self.cfg["keysFile"])}))
        # The guard replays the journal from the start of the second it starts
        # in; a fresh second keeps the previous test's logins out of that.
        time.sleep(1)
        self.since = int(time.time())
        # Type=notify, as in the real unit: returns once the guard is watching.
        run(["systemd-run", "--quiet", f"--unit={UNIT}", "--collect", "-p", "Type=notify",
             "-p", "Restart=on-failure", "-E", f"AGENT_WORK_DISK_CONFIG={config}", GUARD, "guard"], check=False)

    def saw(self, pattern: str, *filters: str) -> bool:
        log = output(["journalctl", "--since", f"@{self.since}", "--no-pager", "-o", "cat", *filters])
        return re.search(pattern, log, re.M) is not None

    def session(self, user: str) -> bool:
        """Open and close a logind session for `user`; whether logind logged it."""
        run(["systemd-run", "--quiet", "--wait", "-E", "XDG_SESSION_CLASS=user", "-p", f"User={user}",
             "-p", "PAMName=login", shutil.which("true")], check=False, quiet=True)
        time.sleep(2)
        return self.saw(rf"^New session '?[^ ']+'? of user '?{re.escape(user)}'?[ .]",
                        "_SYSTEMD_UNIT=systemd-logind.service")

    def ssh_login(self, hold: bool = False) -> bool:
        """SSH in as the user with the test key; whether that worked. With
        `hold`, the session stays open until close_sessions."""
        command = "echo $XDG_SESSION_ID" + ("; exec sleep 600" if hold else "")
        login = subprocess.Popen(
            [str(c) for c in ["runuser", "-u", self.user, "--", "ssh", "-n", "-i", self.tmp / "ssh" / "id",
                              "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no",
                              "-o", "UserKnownHostsFile=/dev/null", f"{self.user}@localhost", command]],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
        assert login.stdout is not None
        session = login.stdout.readline().strip()
        if session:
            self.sessions.add(session)
        if hold:
            self.held = login
        else:
            login.wait()
        return bool(session)

    def expect_running(self, label: str) -> None:
        time.sleep(2)
        self.check(active(UNIT), f"{label}: guard kept running")
        self.check(os.path.ismount(MOUNT), f"{label}: disk still mounted")

    def expect_locked(self, label: str) -> None:
        for _ in range(150):
            if not active(UNIT):
                break
            time.sleep(0.1)
        else:
            self.check(False, f"{label}: guard still running after 15s")
            return
        self.check(self.saw(f"^locking {MOUNT}: ", "-t", "agent-work-disk"), f"{label}: guard fired")
        self.check(not os.path.ismount(MOUNT), f"{label}: unmounted")
        self.check(not mapped(), f"{label}: LUKS mapping closed")
        # poll() reaps our own children, so None means still alive.
        self.check(self.holder.poll() is not None, f"{label}: process on the disk killed")
        self.check(self.bystander.poll() is None, f"{label}: unrelated process untouched")
        self.stop_helpers()

    def run(self) -> int:
        print(f"setting up a throwaway LUKS disk at {MOUNT}", flush=True)
        self.setup()
        self.mount_disk()

        print(f"1. session for {self.user}, should be ignored", flush=True)
        self.start_guard()
        if self.session(self.user):
            self.expect_running("own session")
        else:
            self.check(False, "own session: logind never logged a session, test inconclusive")

        print(f"2. SSH login as {self.user} with a trusted key, should be ignored", flush=True)
        self.start_guard(self.tmp / "trusted.pub")
        if self.ssh_login():
            self.expect_running("trusted key")
        else:
            self.check(False, "trusted key: ssh login to localhost failed, test inconclusive")
        self.close_sessions()

        print(f"3. SSH login as {self.user} with an unknown key, should lock", flush=True)
        self.start_guard()
        self.ssh_login()
        self.expect_locked("unknown key")
        self.close_sessions()

        print("4. session for nobody, should lock", flush=True)
        self.mount_disk()
        self.start_guard()
        if self.session("nobody"):
            self.expect_locked("foreign session")
        else:
            print("SKIP  foreign session: PAM refused a session for nobody")
        self.close_sessions()

        print("5. SSH login with an unknown key, open before the guard starts, should lock", flush=True)
        self.mount_disk()
        if self.ssh_login(hold=True):
            self.start_guard()
            self.expect_locked("already open")
        else:
            self.check(False, "already open: ssh login to localhost failed, test inconclusive")
        self.close_sessions()

        print("some checks failed" if self.failed else "all checks passed")
        return int(self.failed)


def main() -> int:
    parser = argparse.ArgumentParser(prog="agent-work-disk-guard-test", description=__doc__.splitlines()[0])
    parser.add_argument("--pause-guard", action="store_true", help="stop the real guard during the test")
    args = parser.parse_args()
    user = os.environ.get("SUDO_USER")
    if os.geteuid() != 0 or not user:
        sys.exit("run as: sudo agent-work-disk-guard-test")
    os.umask(0o077)
    cfg = json.loads(CONFIG.read_text())
    unit = cfg["guardUnit"]
    paused = active(unit)
    if paused and not args.pause_guard:
        sys.exit(f"{unit} is running and a test login would lock {cfg['mountPoint']}; "
                 "rerun with --pause-guard to stop it for the test")
    try:
        if paused:
            run(["systemctl", "stop", unit])
        run(["systemctl", "stop", UNIT], check=False, quiet=True)
        test = GuardTest(cfg, user)
        try:
            return test.run()
        finally:
            test.cleanup()
    finally:
        # Also after a crash: never leave the real disk without its guard.
        if paused:
            if run(["systemctl", "start", unit], check=False).returncode == 0 and active(unit):
                print(f"{unit} re-armed")
            else:
                print(f"FAILED to re-arm {unit}; run `sudo systemctl start {unit}`", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
