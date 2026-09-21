# keychain.sh - meant to be sourced in .bash_profile/.zshrc

# Give background services a stable path while SSH sessions change their sockets.
# Empty agents (including a local GPG agent) must not replace a working forward.
publish_ssh_agent() {
    local agent_socket="${1:-${SSH_AUTH_SOCK:-}}"
    local stable_socket="$HOME/.ssh/t3-agent.sock"
    local temporary_link
    [[ -S "$agent_socket" ]] || return 1
    [[ "$agent_socket" == /* ]] || agent_socket="$PWD/$agent_socket"
    SSH_AUTH_SOCK="$agent_socket" ssh-add -l >/dev/null 2>&1 || return 1
    [[ "$agent_socket" -ef "$stable_socket" ]] && return 0
    [[ -d "$stable_socket" ]] && return 1
    [[ ! -e "$stable_socket" || -L "$stable_socket" ]] || return 1
    (umask 077; mkdir -p "$HOME/.ssh") || return 1
    temporary_link=$(mktemp "$HOME/.ssh/.t3-agent.XXXXXXXX") || return 1
    if ln -sfn "$agent_socket" "$temporary_link" && mv -f "$temporary_link" "$stable_socket"; then
        return 0
    fi
    rm -f "$temporary_link"
    return 1
}

fixssh() {
    local agent_socket="${1:-${SSH_AUTH_SOCK:-}}"
    local candidate
    if [[ $# -eq 0 ]]; then
        # Refresh stale multiplexer sessions; ignore disconnected agents.
        while IFS= read -r candidate; do
            case "$candidate" in
                s.*.sshd.*)
                    if publish_ssh_agent "$HOME/.ssh/agent/$candidate"; then
                        agent_socket="$HOME/.ssh/agent/$candidate"
                        break
                    fi
                    ;;
            esac
        done < <(command ls -t "$HOME/.ssh/agent" 2>/dev/null)
    fi
    if [[ -n "$agent_socket" && "$agent_socket" != /* ]]; then
        agent_socket="$PWD/$agent_socket"
    fi
    if ! publish_ssh_agent "$agent_socket"; then
        printf 'No usable SSH agent could be published from %s\n' "${agent_socket:-<unset>}" >&2
        return 1
    fi
    export SSH_AUTH_SOCK="$agent_socket"
    ssh-add -l
}

# Preserve SSH agent forwarding in remote sessions.
# If SSH provided a valid forwarded agent socket, keep it instead of overriding
# SSH_AUTH_SOCK with a local keychain-managed agent.
use_forwarded_agent=false
if [[ -n "${SSH_CONNECTION:-}" && -S "${SSH_AUTH_SOCK:-}" ]]; then
    agent_status=0
    ssh-add -l >/dev/null 2>&1 || agent_status=$?
    if [[ $agent_status -eq 0 || $agent_status -eq 1 ]]; then
        use_forwarded_agent=true
    fi
fi

# Check if keychain is installed and the key exists
if [[ "$use_forwarded_agent" != true ]] && command -v keychain &> /dev/null && [[ -f ~/.ssh/id_ed25519 ]]; then
    # On macOS, use 1Password (if available) to provide passphrase for SSH keys
    if [[ `uname` == 'Darwin' ]] && command -v op &> /dev/null; then
        # Set SSH_ASKPASS to use the 1Password helper script for passphrase prompts
        export SSH_ASKPASS="$HOME/.ssh/askpass-1password.sh"
        # Ensure ssh-add uses SSH_ASKPASS even in non-graphical/terminal sessions.
        export SSH_ASKPASS_REQUIRE="prefer"
    fi

    # Execute keychain:
    # --eval: Output shell commands (export SSH_AUTH_SOCK=...; export SSH_AGENT_PID=...)
    # --quiet: Suppress informational messages.
    # id_ed25519: The specific key to load into the agent (will use SSH_ASKPASS).
    if [ -t 0 ]; then
        # Interactive terminal - allow prompting
        eval $(keychain --eval --quiet id_ed25519) || true
    else
        # Non-interactive (like during login) - don't prompt
        eval $(keychain --eval --quiet --noask id_ed25519)
    fi

    # Clean up the temporary ASKPASS variables; they are only needed when adding keys.
    unset SSH_ASKPASS
    unset SSH_ASKPASS_REQUIRE

    # Or use 1Password SSH agent (https://developer.1password.com/docs/ssh/get-started/)
    # export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
fi

# This only records a socket path; authentication still requires the live agent.
publish_ssh_agent >/dev/null 2>&1 || true
