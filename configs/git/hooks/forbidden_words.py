#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

DEFAULT_VISIBILITY_TTL = 24 * 60 * 60
RULES_REPOSITORY_PATH = "configs/git/forbidden-words"
PRIVATE_VISIBILITIES = {"PRIVATE", "INTERNAL"}
KNOWN_VISIBILITIES = PRIVATE_VISIBILITIES | {"PUBLIC"}


@dataclass(frozen=True)
class Rule:
    word: str
    reason: str


@dataclass(frozen=True)
class Violation:
    location: str
    rule: Rule


def git(
    *arguments: str, input_text: str | None = None
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *arguments],
        check=False,
        capture_output=True,
        input=input_text,
        text=True,
    )


def config_directory() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "git"


def cache_directory() -> Path:
    return (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
        / "git-forbidden-words"
    )


def load_rules() -> list[Rule]:
    rules: list[Rule] = []
    paths = [
        config_directory() / "forbidden-words",
        config_directory() / "forbidden-words.private",
    ]
    for path in paths:
        if not path.exists():
            continue
        for line_number, raw_line in enumerate(path.read_text().splitlines(), start=1):
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "\t" not in raw_line:
                raise ValueError(f"{path}:{line_number}: expected word<TAB>reason")
            word, reason = (part.strip() for part in raw_line.split("\t", 1))
            if not word or not reason:
                raise ValueError(
                    f"{path}:{line_number}: word and reason must be non-empty"
                )
            rules.append(Rule(word=word, reason=reason))
    return rules


def remote_url() -> str | None:
    origin = git("remote", "get-url", "origin")
    if origin.returncode == 0 and origin.stdout.strip():
        return origin.stdout.strip()
    remotes = git("remote")
    if remotes.returncode != 0 or not remotes.stdout.splitlines():
        return None
    fallback = git("remote", "get-url", remotes.stdout.splitlines()[0])
    if fallback.returncode != 0:
        return None
    return fallback.stdout.strip() or None


def visibility_ttl() -> int:
    raw_ttl = os.environ.get(
        "GIT_FORBIDDEN_WORDS_VISIBILITY_TTL", str(DEFAULT_VISIBILITY_TTL)
    )
    try:
        return max(0, int(raw_ttl))
    except ValueError:
        return DEFAULT_VISIBILITY_TTL


def cache_path(remote: str) -> Path:
    key = hashlib.sha256(remote.encode()).hexdigest()[:20]
    return cache_directory() / f"{key}.json"


def read_cached_visibility(path: Path, now: int) -> str | None:
    try:
        cached = json.loads(path.read_text())
        checked_at = int(cached["checked_at"])
        visibility = str(cached["visibility"])
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None
    age = now - checked_at
    if 0 <= age < visibility_ttl():
        return visibility
    return None


def write_cached_visibility(path: Path, visibility: str, now: int) -> None:
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_text(json.dumps({"checked_at": now, "visibility": visibility}))
        temporary.replace(path)
    except OSError:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass


def repository_visibility() -> str:
    remote = remote_url()
    if remote is None:
        return "UNKNOWN"
    path = cache_path(remote)
    now = int(time.time())
    cached = read_cached_visibility(path, now)
    if cached is not None:
        return cached
    try:
        result = subprocess.run(
            [
                "gh",
                "repo",
                "view",
                remote,
                "--json",
                "visibility",
                "--jq",
                ".visibility",
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        visibility = result.stdout.strip().upper()
        if result.returncode != 0 or visibility not in KNOWN_VISIBILITIES:
            visibility = "UNKNOWN"
    except (OSError, subprocess.TimeoutExpired):
        visibility = "UNKNOWN"
    write_cached_visibility(path, visibility, now)
    return visibility


def staged_paths() -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        return []
    return [os.fsdecode(path) for path in result.stdout.split(b"\0") if path]


def added_text(path: str) -> str:
    result = git(
        "diff",
        "--cached",
        "--unified=0",
        "--no-color",
        "--diff-filter=ACMR",
        "--",
        path,
    )
    if result.returncode != 0:
        return ""
    added_lines: list[str] = []
    in_hunk = False
    for line in result.stdout.splitlines():
        if line.startswith("@@ "):
            in_hunk = True
        elif in_hunk and line.startswith("+"):
            added_lines.append(line[1:])
    return "\n".join(added_lines)


def find_staged_violations(rules: list[Rule]) -> list[Violation]:
    violations: list[Violation] = []
    for path in staged_paths():
        if Path(path).as_posix() == RULES_REPOSITORY_PATH:
            continue
        folded_text = added_text(path).casefold()
        for rule in rules:
            if rule.word.casefold() in folded_text:
                violations.append(Violation(location=path, rule=rule))
    return violations


def commit_message_text(path: Path) -> str:
    try:
        message = path.read_text()
    except OSError:
        return ""
    stripped = git("stripspace", "--strip-comments", input_text=message)
    return stripped.stdout if stripped.returncode == 0 else message


def find_message_violations(path: Path, rules: list[Rule]) -> list[Violation]:
    folded_message = commit_message_text(path).casefold()
    return [
        Violation(location="commit message", rule=rule)
        for rule in rules
        if rule.word.casefold() in folded_message
    ]


def print_violations(violations: list[Violation]) -> None:
    print("Commit blocked by forbidden-word rules:", file=sys.stderr)
    for violation in violations:
        print(
            f"  {violation.location}: {violation.rule.word} - {violation.rule.reason}",
            file=sys.stderr,
        )


def local_hook_path(hook_name: str) -> Path | None:
    common_dir = git("rev-parse", "--git-common-dir")
    if common_dir.returncode != 0:
        return None
    path = Path(common_dir.stdout.strip())
    if not path.is_absolute():
        path = Path.cwd() / path
    return path / "hooks" / hook_name


def run_local_hook(
    hook_name: str, arguments: list[str], current_hook: Path
) -> tuple[bool, int]:
    local_hook = local_hook_path(hook_name)
    if local_hook is None or not os.access(local_hook, os.X_OK):
        return False, 0
    if local_hook.resolve() == current_hook.resolve():
        return False, 0
    status = subprocess.run([str(local_hook), *arguments], check=False).returncode
    return True, status


def run_pre_commit_framework(hook_name: str, arguments: list[str]) -> int:
    if hook_name not in {"pre-commit", "commit-msg"}:
        return 0
    if not Path(".pre-commit-config.yaml").is_file():
        return 0
    command = ["pre-commit", "run", "--hook-stage", hook_name]
    if hook_name == "commit-msg" and arguments:
        command.extend(["--commit-msg-filename", arguments[0]])
    try:
        return subprocess.run(command, check=False).returncode
    except OSError as error:
        print(f"Cannot run repository pre-commit checks: {error}", file=sys.stderr)
        return 1


def run_hook(hook_name: str, arguments: list[str], current_hook: Path) -> int:
    local_hook_found, local_status = run_local_hook(hook_name, arguments, current_hook)
    if local_status != 0:
        return local_status
    if not local_hook_found:
        framework_status = run_pre_commit_framework(hook_name, arguments)
        if framework_status != 0:
            return framework_status
    if repository_visibility() not in PRIVATE_VISIBILITIES:
        try:
            rules = load_rules()
        except (OSError, UnicodeError, ValueError) as error:
            print(f"Forbidden-word configuration error: {error}", file=sys.stderr)
            return 1
        if hook_name == "pre-commit":
            violations = find_staged_violations(rules)
        elif hook_name == "commit-msg" and arguments:
            violations = find_message_violations(Path(arguments[0]), rules)
        else:
            violations = []
        if violations:
            print_violations(violations)
            return 1
    return 0
