#!/usr/bin/env python3
"""Hook to block git commit --amend and git push --force commands."""

import json
import re
import sys

# Pre-compile the blocking pattern for efficiency
BLOCKED_REGEX = re.compile(
    r"\bgit\s+(?:"
    r"commit\b.*--amend|"
    r"push\b.*(?:--force|-f|--force-with-lease)"
    r")\b",
    re.IGNORECASE,
)


def main():
    try:
        if sys.stdin.isatty():
            return

        input_data = json.load(sys.stdin)
        tool_name = input_data.get("tool_name", "")

        # We only care about RunShellCommand
        # Note: Documentation refers to "RunShellCommand" (PascalCase) but source code
        # uses "run_shell_command" (snake_case). We check for both to be safe.
        if tool_name.lower() not in ("runshellcommand", "run_shell_command"):
            print(json.dumps({"decision": "allow"}))
            return

        command = input_data.get("tool_input", {}).get("command", "")
        if not command:
            print(json.dumps({"decision": "allow"}))
            return

        # Check for blocked pattern
        if BLOCKED_REGEX.search(command):
            print(
                json.dumps({
                    "decision": "deny",
                    "reason": "Git rewrite history commands (amend, force push) are not allowed",
                    "systemMessage": "🚫 Blocked: Git rewrite history commands are not allowed",
                })
            )
            return

    except (json.JSONDecodeError, AttributeError, BrokenPipeError):
        pass
    except Exception as e:
        print(f"Hook error: {e}", file=sys.stderr)

    print(json.dumps({"decision": "allow"}))


if __name__ == "__main__":
    main()
