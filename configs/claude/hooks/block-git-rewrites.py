#!/usr/bin/env python3
"""Hook to block git commit --amend and git push --force commands."""
import json
import re
import sys

# Patterns to block
BLOCKED_PATTERNS = [
    (r"\bgit\s+commit\b.*--amend\b", "git commit --amend is not allowed"),
    (r"\bgit\s+push\b.*--force\b", "git push --force is not allowed"),
    (r"\bgit\s+push\b.*-f\b", "git push -f (force) is not allowed"),
    (r"\bgit\s+push\b.*--force-with-lease\b", "git push --force-with-lease is not allowed"),
]

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

sys.exit(0)
