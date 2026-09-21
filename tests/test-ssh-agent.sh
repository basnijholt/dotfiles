#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# macOS TMPDIR can exceed the Unix socket path limit once fixture names are added.
test_root=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/dotfiles-ssh.XXXXXXXX")
agent_pids=()
cleanup() {
  for agent_pid in "${agent_pids[@]}"; do
    kill "$agent_pid" 2>/dev/null || true
  done
  rm -rf "$test_root"
}
trap cleanup EXIT

# Real agents with distinct throwaway keys exercise socket replacement and SSH consumers.
for agent_name in first second empty bash-disconnect zsh-disconnect; do
  agent_pid=$(ssh-agent -s -a "$test_root/$agent_name.sock" | sed -n 's/SSH_AGENT_PID=\([0-9]*\);.*/\1/p')
  agent_pids+=("$agent_pid")
  case "$agent_name" in
    bash-disconnect) bash_disconnect_pid="$agent_pid" ;;
    zsh-disconnect) zsh_disconnect_pid="$agent_pid" ;;
  esac
  if [[ $agent_name != empty ]]; then
    ssh-keygen -q -t ed25519 -N '' -C "test-$agent_name" -f "$test_root/$agent_name.key"
    SSH_AUTH_SOCK="$test_root/$agent_name.sock" ssh-add "$test_root/$agent_name.key" >/dev/null 2>&1
  fi
done

for test_shell in bash zsh; do
  command -v "$test_shell" >/dev/null || continue
  test_home="$test_root/$test_shell home"
  mkdir -p "$test_home/.ssh/agent"
  ln -s "$test_root/first.sock" "$test_home/.ssh/agent/s.test.sshd.first"
  first_fingerprint=$(ssh-keygen -lf "$test_root/first.key.pub" | awk '{print $2}')
  second_fingerprint=$(ssh-keygen -lf "$test_root/second.key.pub" | awk '{print $2}')
  case "$test_shell" in
    bash) disconnect_pid="$bash_disconnect_pid" ;;
    zsh) disconnect_pid="$zsh_disconnect_pid" ;;
  esac

  env HOME="$test_home" SSH_AUTH_SOCK="$test_home/.ssh/agent/s.test.sshd.first" \
    SSH_CONNECTION='127.0.0.1 1234 127.0.0.1 22' \
    TEST_AGENT_CONFIG="$repo_root/configs/shell/40_keychain.sh" \
    TEST_AGENT_ROOT="$test_root" TEST_FIRST_FP="$first_fingerprint" TEST_SECOND_FP="$second_fingerprint" \
    TEST_SHELL="$test_shell" TEST_DISCONNECT_PID="$disconnect_pid" \
    "$test_shell" -f -c '
      set -eu
      fail() { printf "%s\n" "$*" >&2; exit 1; }
      source "$TEST_AGENT_CONFIG"
      stable_socket="$HOME/.ssh/t3-agent.sock"
      [[ -S "$stable_socket" ]] || fail "shell startup did not publish the forwarded agent"

      # A long-running service keeps this same socket path for every request.
      service_identity() { SSH_AUTH_SOCK="$stable_socket" ssh-add -l 2>/dev/null; }
      [[ $(service_identity) == *"$TEST_FIRST_FP"* ]] || fail "service cannot use the first agent"

      # A reconnect publishes the new socket without changing the service environment.
      SSH_AUTH_SOCK="$TEST_AGENT_ROOT/second.sock"
      source "$TEST_AGENT_CONFIG"
      [[ $(service_identity) == *"$TEST_SECOND_FP"* ]] || fail "service kept the previous agent after reconnect"

      # A local keychain must preserve modern forwarded sockets, then publish local keys when needed.
      cp "$TEST_AGENT_ROOT/first.key" "$HOME/.ssh/id_ed25519"
      keychain() { printf "export SSH_AUTH_SOCK=\"%s\"\n" "$TEST_AGENT_ROOT/first.sock"; }
      source "$TEST_AGENT_CONFIG"
      [[ "$SSH_AUTH_SOCK" == "$TEST_AGENT_ROOT/second.sock" ]] || fail "keychain replaced a working forwarded agent"
      SSH_CONNECTION=
      SSH_AUTH_SOCK="$TEST_AGENT_ROOT/empty.sock"
      source "$TEST_AGENT_CONFIG"
      [[ $(service_identity) == *"$TEST_FIRST_FP"* ]] || fail "newly initialized local agent was not published"
      unset -f keychain
      rm "$HOME/.ssh/id_ed25519"
      SSH_AUTH_SOCK="$TEST_AGENT_ROOT/second.sock"
      source "$TEST_AGENT_CONFIG"

      # T3-spawned shells may point to the stable socket or an empty local GPG agent.
      SSH_AUTH_SOCK="$stable_socket"
      source "$TEST_AGENT_CONFIG"
      [[ $(service_identity) == *"$TEST_SECOND_FP"* ]] || fail "publishing the stable socket created a loop"
      SSH_CONNECTION=
      SSH_AUTH_SOCK="$TEST_AGENT_ROOT/empty.sock"
      source "$TEST_AGENT_CONFIG"
      [[ $(service_identity) == *"$TEST_SECOND_FP"* ]] || fail "empty local agent replaced the forwarded agent"
      SSH_AUTH_SOCK=
      source "$TEST_AGENT_CONFIG"
      [[ $(service_identity) == *"$TEST_SECOND_FP"* ]] || fail "a shell without an agent removed the working link"

      # fixssh can explicitly select an agent and rejects unusable inputs without losing it.
      fixssh "$TEST_AGENT_ROOT/first.sock" >/dev/null
      [[ $(service_identity) == *"$TEST_FIRST_FP"* ]] || fail "fixssh did not update the service socket"
      old_socket="$SSH_AUTH_SOCK"
      if fixssh "$TEST_AGENT_ROOT/missing.sock" 2>/dev/null; then
        fail "fixssh accepted a missing socket"
      fi
      [[ "$SSH_AUTH_SOCK" == "$old_socket" ]] || fail "failed fixssh changed the shell agent"
      [[ $(service_identity) == *"$TEST_FIRST_FP"* ]] || fail "failed fixssh lost the working service agent"

      # Existing automatic discovery still works from a stale multiplexer shell.
      SSH_AUTH_SOCK="$TEST_AGENT_ROOT/empty.sock"
      fixssh >/dev/null
      [[ $(service_identity) == *"$TEST_FIRST_FP"* ]] || fail "fixssh did not discover the forwarded socket"

      # Publishing a reconnect must not leave a missing socket between the two agents.
      (
        for attempt in $(seq 1 100); do
          publish_ssh_agent "$TEST_AGENT_ROOT/first.sock"
          publish_ssh_agent "$TEST_AGENT_ROOT/second.sock"
        done
      ) &
      writer_pid=$!
      missing_socket=false
      while kill -0 "$writer_pid" 2>/dev/null; do
        if [[ ! -S "$stable_socket" ]]; then
          missing_socket=true
          break
        fi
      done
      wait "$writer_pid"
      [[ "$missing_socket" == false ]] || fail "socket disappeared while a reconnect was published"

      # Relative arguments must keep working after the caller changes directories.
      (
        cd "$TEST_AGENT_ROOT"
        fixssh first.sock >/dev/null
        cd "$HOME"
        [[ $(ssh-add -l) == *"$TEST_FIRST_FP"* ]] || fail "relative fixssh argument left the shell with an unusable agent"
        [[ $(service_identity) == *"$TEST_FIRST_FP"* ]] || fail "relative fixssh argument created a broken service link"
      )

      # A real disconnect revokes access, and a later login restores the same service path.
      fixssh "$TEST_AGENT_ROOT/$TEST_SHELL-disconnect.sock" >/dev/null
      kill "$TEST_DISCONNECT_PID"
      attempts=0
      while service_identity >/dev/null; do
        attempts=$((attempts + 1))
        [[ $attempts -lt 20 ]] || fail "service still reached the disconnected agent"
        sleep 0.05
      done
      SSH_AUTH_SOCK="$TEST_AGENT_ROOT/second.sock"
      source "$TEST_AGENT_CONFIG"
      [[ $(service_identity) == *"$TEST_SECOND_FP"* ]] || fail "reconnect did not restore service authentication"

      # Never overwrite an unrelated file at the chosen stable path.
      rm "$stable_socket"
      printf "keep this file\n" > "$stable_socket"
      if fixssh "$TEST_AGENT_ROOT/first.sock" 2>/dev/null; then
        fail "fixssh overwrote a regular file"
      fi
      [[ $(cat "$stable_socket") == "keep this file" ]] || fail "regular file was modified"
    '
  printf '%s SSH-agent tests passed\n' "$test_shell"
done
