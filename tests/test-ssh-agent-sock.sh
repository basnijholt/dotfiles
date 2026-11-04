#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/configs/nixos/common/ssh-agent-sock.sh"
test_root=$(mktemp -d)
agent_pids=()
cleanup() {
  for pid in "${agent_pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  rm -rf "$test_root"
}
trap cleanup EXIT

home="$test_root/home"
mkdir -p "$home/.ssh/agent" "$home/.keychain"
ssh-keygen -q -t ed25519 -N '' -f "$test_root/key"

start_agent() {
  agent_pid=$(ssh-agent -s -a "$1" | sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p')
  agent_pids+=("$agent_pid")
}

start_agent_with_key() {
  start_agent "$1"
  SSH_AUTH_SOCK=$1 ssh-add -q "$test_root/key"
}

stop_agent() {
  kill -9 "$1"
  while kill -0 "$1" 2>/dev/null; do :; done
}

expect() {
  local got
  got=$(HOME=$home bash "$script") || true
  if [[ "$got" != "$1" ]]; then
    printf 'ssh-agent-sock printed %q, expected %q\n' "$got" "$1" >&2
    exit 1
  fi
}

# Oldest to newest: keychain, a live forwarded agent, an empty agent, and a
# dead forwarded socket that sshd left behind.
start_agent_with_key "$home/.keychain/host.s"
start_agent_with_key "$home/.ssh/agent/s.host.sshd.live"
live_pid=$agent_pid
start_agent "$home/.ssh/agent/s.host.agent.empty"
start_agent "$home/.ssh/agent/s.host.sshd.dead"
stop_agent "$agent_pid"

expect "$home/.ssh/agent/s.host.sshd.live"
stop_agent "$live_pid"
expect "$home/.keychain/host.s"

printf 'ssh-agent-sock tests passed\n'
