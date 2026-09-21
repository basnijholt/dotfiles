# keychain.sh - meant to be sourced in .bash_profile/.zshrc

# Preserve SSH agent forwarding in remote sessions.
# If SSH provided a valid forwarded agent socket, keep it instead of overriding
# SSH_AUTH_SOCK with a local keychain-managed agent.
use_forwarded_agent=false
if [[ -n "${SSH_CONNECTION:-}" && -n "${SSH_AUTH_SOCK:-}" && "${SSH_AUTH_SOCK}" == /tmp/ssh-*/agent.* ]]; then
    ssh-add -l >/dev/null 2>&1
    agent_status=$?
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
