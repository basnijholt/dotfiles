#!/usr/bin/env bash
# Print the newest SSH agent socket whose agent holds a key.
# ~/.ssh/agent has sshd's forwarded sockets and ssh-agent's (OpenSSH 10.1+);
# sshd can leave dead ones behind, so each is tried. keychain's agent is last.
set -euo pipefail

for sock in $(ls -t "$HOME"/.ssh/agent/s.* 2>/dev/null) "$HOME"/.keychain/*.s; do
  if SSH_AUTH_SOCK=$sock ssh-add -l >/dev/null 2>&1; then
    echo "$sock"
    exit 0
  fi
done
exit 1
