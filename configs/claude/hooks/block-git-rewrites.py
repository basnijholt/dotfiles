#!/usr/bin/env python3
"""Hook to block dangerous git commands: amend, force push, and push to main."""

import json
import re
import subprocess
import sys

# Patterns to block
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
    # Pattern: "git push" optionally followed by remote name, but no branch specified
    # This matches: "git push", "git push origin", "git push -u origin"
    # But not: "git push origin feature-branch"
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


try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
    sys.exit(1)

tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})
command = tool_input.get("command", "")

if tool_name != "Bash" or not command:
    sys.exit(0)

# Check for blocked patterns
for pattern, message in BLOCKED_PATTERNS:
    if re.search(pattern, command, re.IGNORECASE):
        print(f"Blocked: {message}", file=sys.stderr)
        sys.exit(2)

# Check for push to protected branch
push_error = is_push_to_protected_branch(command)
if push_error:
    print(f"Blocked: {push_error}", file=sys.stderr)
    sys.exit(2)

sys.exit(0)
