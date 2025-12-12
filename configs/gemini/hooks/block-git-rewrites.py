#!/usr/bin/env python3
"""Hook to block dangerous git commands: amend, force push, and push to main."""

import json
import re
import subprocess
import sys

# Pre-compile the blocking pattern for efficiency
BLOCKED_REGEX = re.compile(
    r"\bgit\s+(?:"
    r"commit\b.*--amend|"
    r"push\b.*(?:--force|-f|--force-with-lease)"
    r")\b",
    re.IGNORECASE,
)

PROTECTED_BRANCHES = {"main", "master"}


def get_current_branch() -> str | None:
    """Get the current git branch name."""
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def is_push_to_protected_branch(command: str) -> str | None:
    """Check if command pushes to a protected branch. Returns error message or None."""
    if not re.search(r"\bgit\s+push\b", command, re.IGNORECASE):
        return None

    # Check for explicit push to protected branch (e.g., git push origin main)
    for branch in PROTECTED_BRANCHES:
        if re.search(rf"\bgit\s+push\b.*\b{branch}\b", command, re.IGNORECASE):
            return f"git push to {branch} is not allowed - use a PR"

    # Check if currently on protected branch and pushing without explicit branch
    push_match = re.search(r"\bgit\s+push\b(.*)$", command, re.IGNORECASE)
    if push_match:
        args = push_match.group(1).strip()
        # Remove flags like -u, --set-upstream, etc.
        args_without_flags = re.sub(r"\s*-[a-zA-Z]\b|\s*--[\w-]+", "", args).strip()
        # Split remaining args - should be at most remote name
        parts = args_without_flags.split()
        # If 0 or 1 parts (no args or just remote), check current branch
        if len(parts) <= 1:
            current_branch = get_current_branch()
            if current_branch in PROTECTED_BRANCHES:
                return f"git push while on {current_branch} is not allowed - use a PR"

    return None


def deny(reason: str) -> None:
    """Print a deny decision and exit."""
    print(
        json.dumps({
            "decision": "deny",
            "reason": reason,
            "systemMessage": f"🚫 Blocked: {reason}",
        })
    )


def allow() -> None:
    """Print an allow decision."""
    print(json.dumps({"decision": "allow"}))


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
            allow()
            return

        command = input_data.get("tool_input", {}).get("command", "")
        if not command:
            allow()
            return

        # Check for blocked rewrite patterns
        if BLOCKED_REGEX.search(command):
            deny("Git rewrite history commands (amend, force push) are not allowed")
            return

        # Check for push to protected branch
        push_error = is_push_to_protected_branch(command)
        if push_error:
            deny(push_error)
            return

    except (json.JSONDecodeError, AttributeError, BrokenPipeError):
        pass
    except Exception as e:
        print(f"Hook error: {e}", file=sys.stderr)

    allow()


if __name__ == "__main__":
    main()
