"""Shared detection logic for the block-git-rewrites hooks (Claude/Codex/Gemini).

Blocks dangerous git commands: amend, force push, push to main, git add -A,
and gh pr merge. Most blocks are overridable: prefixing the command with
OVERRIDE_MARKER (only when the user explicitly approved the action in
conversation) lets the tool-specific adapter escalate or allow it.
git add -A/--all is never overridable.

This lives in claude/hooks as the canonical copy; the Codex hook is a symlink
to the adapter here, and the Gemini adapter imports this module by path.
"""

import re
import subprocess

OVERRIDE_MARKER = "EXPLICITLY_USER_APPROVED_HOOK_OVERRIDE=1"

# Regex pattern for git with optional global options before subcommand
# Matches: git push, git -C /path push, git --git-dir=/path push
# Does NOT match: git stash push, git log | grep push
# Options can be: -X, -X value, --long, --long=value
_GIT_OPT = r"(?:-[a-zA-Z](?:\s+[^-\s]\S*)?|--[\w-]+(?:=\S+)?)"
_GIT_OPTS = rf"(?:\s+{_GIT_OPT})*"  # zero or more option groups
_GIT_CMD = rf"\bgit\b{_GIT_OPTS}\s+"  # git followed by options then space

# Patterns to block dangerous git commands: (pattern, message, overridable)
BLOCKED_PATTERNS = [
    (rf"{_GIT_CMD}commit\b.*--amend\b", "git commit --amend is not allowed", True),
    (rf"{_GIT_CMD}push\b.*--force\b", "git push --force is not allowed", True),
    (rf"{_GIT_CMD}push\b.*-f\b", "git push -f (force) is not allowed", True),
    (rf"{_GIT_CMD}push\b.*--force-with-lease\b", "git push --force-with-lease is not allowed", True),
    (rf"{_GIT_CMD}add\b.*-A\b", "git add -A is not allowed - add files explicitly to avoid adding unrelated untracked files", False),
    (rf"{_GIT_CMD}add\b.*--all\b", "git add --all is not allowed - add files explicitly to avoid adding unrelated untracked files", False),
    (r"\bgh\s+pr\s+merge\b", "gh pr merge is not allowed - the user must merge PRs themselves, never the agent", True),
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


def extract_git_directory(command: str) -> str | None:
    """Extract the directory from git -C flag if present.

    Handles: git -C /path, git -C"/path", git -C '/path'
    """
    # Match -C with optional space, then quoted or unquoted path
    match = re.search(
        r"\bgit\s+-C\s*(?:\"([^\"]+)\"|'([^']+)'|(\S+))",
        command,
    )
    if match:
        return match.group(1) or match.group(2) or match.group(3)
    return None


def get_current_branch(git_dir: str | None = None) -> str | None:
    """Get the current git branch name.

    Args:
        git_dir: Optional directory to check (for git -C support)
    """
    try:
        cmd = ["git"]
        if git_dir:
            cmd.extend(["-C", git_dir])
        cmd.extend(["branch", "--show-current"])
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def check_blocked_patterns(command: str) -> tuple[str, bool] | None:
    """Check if command matches any blocked pattern.

    Returns (error message, overridable) if blocked, None if allowed.
    """
    for pattern, message, overridable in BLOCKED_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return message, overridable
    return None


def check_push_to_protected_branch(
    command: str, original_command: str | None = None
) -> str | None:
    """Check if command pushes to a protected branch.

    Args:
        command: The command to check (may have quotes stripped)
        original_command: Original command with quotes intact (for -C extraction)

    Returns error message if blocked, None if allowed.
    """
    # Pattern: git (with optional global options) push
    git_push_pattern = rf"{_GIT_CMD}push\b"
    if not re.search(git_push_pattern, command, re.IGNORECASE):
        return None

    # Check for explicit push to protected branch (e.g., git push origin main)
    for branch in PROTECTED_BRANCHES:
        if re.search(rf"{_GIT_CMD}push\b.*\b{branch}\b", command, re.IGNORECASE):
            return f"git push to {branch} is not allowed - use a PR"

    # Check if currently on protected branch and pushing without explicit branch
    # This matches: "git push", "git push origin", "git -C /path push"
    # But not: "git push origin feature-branch", "git stash push"
    push_match = re.search(rf"{_GIT_CMD}push\b(.*)$", command, re.IGNORECASE)
    if push_match:
        args = push_match.group(1).strip()
        # Remove flags like -u, --set-upstream, etc.
        args_without_flags = re.sub(r"\s*-[a-zA-Z]\b|\s*--[\w-]+", "", args).strip()
        parts = args_without_flags.split()
        # If 0 or 1 parts (no args or just remote), check current branch
        if len(parts) <= 1:
            # Extract -C directory from original command (preserves quoted paths)
            git_dir = extract_git_directory(original_command or command)
            current_branch = get_current_branch(git_dir)
            if current_branch in PROTECTED_BRANCHES:
                return f"git push while on {current_branch} is not allowed - use a PR"

    return None


def split_shell_commands(command: str) -> list[str]:
    """Split a shell command string on command separators.

    Splits on &&, ||, ;, and | to handle each command individually.
    This ensures 'git push && other' doesn't treat '&& other' as push args.
    """
    # Split on shell command separators, keeping it simple
    # This handles: cmd1 && cmd2, cmd1 || cmd2, cmd1 ; cmd2, cmd1 | cmd2
    parts = re.split(r"\s*(?:&&|\|\||[;|])\s*", command)
    return [p.strip() for p in parts if p.strip()]


def check_command(command: str) -> tuple[str, bool] | None:
    """Check a shell command for dangerous git operations.

    Returns (error message, overridable) if blocked, None if allowed.
    """
    stripped = strip_quoted_strings(command)

    # Split on shell separators and check each command individually
    for cmd in split_shell_commands(stripped):
        result = check_blocked_patterns(cmd)
        if result:
            return result

        # For branch detection, find corresponding original command segment
        # Use the full original for -C extraction (it's OK if imprecise)
        error = check_push_to_protected_branch(cmd, original_command=command)
        if error:
            return error, True

    return None


def has_override(command: str) -> bool:
    """Check if the command carries the user-approved override marker."""
    return OVERRIDE_MARKER in command


def override_hint() -> str:
    """Standard hint appended to block messages for overridable rules."""
    return (
        f"\nIf (and only if) the user has explicitly approved this exact action, "
        f"re-run the command prefixed with {OVERRIDE_MARKER} to override this block."
    )
