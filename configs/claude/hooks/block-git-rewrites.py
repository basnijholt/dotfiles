#!/usr/bin/env python3
"""Hook to block dangerous git commands: amend, force push, and push to main."""

import json
import re
import subprocess
import sys

# Patterns to block dangerous git commands
BLOCKED_PATTERNS = [
    (r"\bgit\s+commit\b.*--amend\b", "git commit --amend is not allowed"),
    (r"\bgit\s+push\b.*--force\b", "git push --force is not allowed"),
    (r"\bgit\s+push\b.*-f\b", "git push -f (force) is not allowed"),
    (
        r"\bgit\s+push\b.*--force-with-lease\b",
        "git push --force-with-lease is not allowed",
    ),
]

PROTECTED_BRANCHES = {"main", "master"}


def strip_quoted_strings(command: str) -> str:
    """Remove quoted strings and heredocs to avoid false positives.

    This prevents matching 'git push' inside commit messages, PR bodies, etc.
    """
    # Remove heredocs: $(cat <<'EOF' ... EOF) or $(cat <<EOF ... EOF)
    result = re.sub(
        r"\$\(cat\s*<<'?(\w+)'?\s*\n.*?\n\s*\1\s*\)",
        " ",
        command,
        flags=re.DOTALL,
    )

    # Remove double-quoted strings (handling escaped quotes)
    result = re.sub(r'"(?:[^"\\]|\\.)*"', " ", result)

    # Remove single-quoted strings (no escaping in single quotes)
    result = re.sub(r"'[^']*'", " ", result)

    return result


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


def check_blocked_patterns(command: str) -> str | None:
    """Check if command matches any blocked pattern.

    Returns error message if blocked, None if allowed.
    """
    for pattern, message in BLOCKED_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return message
    return None


def check_push_to_protected_branch(command: str) -> str | None:
    """Check if command pushes to a protected branch.

    Returns error message if blocked, None if allowed.
    """
    if not re.search(r"\bgit\s+push\b", command, re.IGNORECASE):
        return None

    # Check for explicit push to protected branch (e.g., git push origin main)
    for branch in PROTECTED_BRANCHES:
        if re.search(rf"\bgit\s+push\b.*\b{branch}\b", command, re.IGNORECASE):
            return f"git push to {branch} is not allowed - use a PR"

    # Check if currently on protected branch and pushing without explicit branch
    # This matches: "git push", "git push origin", "git push -u origin"
    # But not: "git push origin feature-branch"
    push_match = re.search(r"\bgit\s+push\b(.*)$", command, re.IGNORECASE)
    if push_match:
        args = push_match.group(1).strip()
        # Remove flags like -u, --set-upstream, etc.
        args_without_flags = re.sub(r"\s*-[a-zA-Z]\b|\s*--[\w-]+", "", args).strip()
        parts = args_without_flags.split()
        # If 0 or 1 parts (no args or just remote), check current branch
        if len(parts) <= 1:
            current_branch = get_current_branch()
            if current_branch in PROTECTED_BRANCHES:
                return f"git push while on {current_branch} is not allowed - use a PR"

    return None


def check_command(command: str) -> str | None:
    """Check a shell command for dangerous git operations.

    Returns error message if blocked, None if allowed.
    """
    stripped = strip_quoted_strings(command)

    error = check_blocked_patterns(stripped)
    if error:
        return error

    return check_push_to_protected_branch(stripped)


# ============================================================================
# Claude Code specific: uses exit codes (0 = allow, 2 = block with stderr)
# ============================================================================


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

    error = check_command(command)
    if error:
        print(f"Blocked: {error}", file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
