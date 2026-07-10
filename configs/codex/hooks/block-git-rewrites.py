#!/usr/bin/env python3
"""Codex adapter for the shared git-guard hook (see shared/hooks/git_guard.py).

Protocol: exit 0 = allow, exit 2 = block with stderr. Codex has no interactive
"ask" escalation, so the override marker allows the command directly.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "shared" / "hooks"))
from git_guard import check_command, has_override, override_hint


def main() -> None:
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    # Only check Bash commands
    if tool_name != "Bash" or not command:
        sys.exit(0)

    result = check_command(command)
    if result:
        error, overridable = result
        if overridable and has_override(command):
            sys.exit(0)
        message = f"Blocked: {error}"
        if overridable:
            message += override_hint()
        print(message, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
