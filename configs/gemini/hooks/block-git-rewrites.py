#!/usr/bin/env python3
"""Gemini CLI adapter for the shared git-guard hook (see claude/hooks/git_guard.py).

Protocol: JSON output with a decision field. Gemini has no interactive "ask"
escalation, so the override marker allows the command directly.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "claude" / "hooks"))
from git_guard import check_command, has_override, override_hint


def deny(reason: str) -> None:
    """Print a deny decision."""
    print(json.dumps({
        "decision": "deny",
        "reason": reason,
        "systemMessage": f"Blocked: {reason}",
    }))


def allow() -> None:
    """Print an allow decision."""
    print(json.dumps({"decision": "allow"}))


def main() -> None:
    try:
        if sys.stdin.isatty():
            allow()
            return

        input_data = json.load(sys.stdin)
        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input", {})
        command = tool_input.get("command", "")

        # Only check RunShellCommand (Gemini's equivalent of Bash)
        if tool_name.lower() not in ("runshellcommand", "run_shell_command"):
            allow()
            return

        if not command:
            allow()
            return

        result = check_command(command)
        if result:
            error, overridable = result
            if not (overridable and has_override(command)):
                if overridable:
                    error += override_hint()
                deny(error)
                return

    except (json.JSONDecodeError, AttributeError, BrokenPipeError):
        pass
    except Exception as e:
        print(f"Hook error: {e}", file=sys.stderr)

    allow()


if __name__ == "__main__":
    main()
