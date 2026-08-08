#!/usr/bin/env python3
"""PreToolUse hook that blocks shell commands leading with `sleep`.

Agents reach for `sleep 240; check-if-done` to wait on a background job, the
guessed duration is almost always a large overshoot, and the wait is
unnecessary: a foreground command already blocks until it finishes, and a
backgrounded one can be polled as soon as it exits.

Only the leading token of each command in a chain is checked, and quoted
strings are stripped first, so `sleep` inside a script being written, a commit
message, or `python -c "time.sleep(1)"` is left alone.

Protocol: exit 0 = allow, exit 2 = block with stderr. The override marker
lifts the block directly (honor system: the agent must only use it after
explicit user approval in conversation).

Shell parsing helpers come from git_guard, the other Bash guard in this dir.
"""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from git_guard import (
    has_override,
    override_hint,
    split_shell_commands,
    strip_quoted_strings,
)

MESSAGE = (
    "sleep is not allowed - the duration is a guess and overshoots by a lot. "
    "Run the command in the foreground and let it block, or start it in the "
    "background and poll its output/exit status instead of sleeping first"
)

# VAR=value prefixes (including the override marker) precede the real command.
_ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")

# Wrappers that can precede the real command without changing what runs.
_WRAPPERS = frozenset({"command", "builtin", "exec", "nohup", "time"})

# A lone & backgrounds the command before it, so what follows starts a new one
# ("pytest & sleep 120"). && and redirections like 2>&1 must survive untouched.
_BACKGROUND = re.compile(r"(?<![&>])&(?!&)")


def leading_command(segment: str) -> str | None:
    """Return the name of the program a shell segment starts with, if any.

    Skips grouping punctuation, environment assignments, and no-op wrappers,
    and reduces a path to its basename: `(FOO=1 /bin/sleep 5` -> `sleep`.
    """
    for token in segment.lstrip("({!&\\ \t").split():
        if _ASSIGNMENT.match(token):
            continue
        name = token.rsplit("/", 1)[-1].lstrip("\\")
        if name in _WRAPPERS:
            continue
        return name
    return None


def starts_with_sleep(command: str) -> bool:
    """Check whether any command in a chain leads with sleep."""
    stripped = _BACKGROUND.sub(";", strip_quoted_strings(command))
    return any(
        leading_command(segment) == "sleep"
        for segment in split_shell_commands(stripped)
    )


def main() -> None:
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    tool_name = input_data.get("tool_name", "")
    command = input_data.get("tool_input", {}).get("command", "")

    # Only check Bash commands
    if tool_name != "Bash" or not command:
        sys.exit(0)

    if starts_with_sleep(command) and not has_override(command):
        print(f"Blocked: {MESSAGE}{override_hint()}", file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
