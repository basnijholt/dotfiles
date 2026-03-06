# Load OpenClaw runtime secrets only for commands that actually need them.

with_openclaw_env() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: with_openclaw_env <command> [args...]" >&2
        return 2
    fi

    (
        local env_file
        for env_file in \
            /run/agenix/openclaw-runtime-env \
            /run/agenix/openclaw-integrations-env \
            /run/agenix/openclaw-tooling-env
        do
            [[ -r "$env_file" ]] || continue
            set -a
            . "$env_file"
            set +a
        done

        exec "$@"
    )
}

openclaw() {
    local openclaw_bin=""
    if [[ -n "$ZSH_VERSION" ]]; then
        openclaw_bin="$(whence -p openclaw 2>/dev/null)"
    else
        openclaw_bin="$(type -P openclaw 2>/dev/null)"
    fi

    if [[ -z "$openclaw_bin" ]]; then
        echo "openclaw: command not found" >&2
        return 127
    fi

    with_openclaw_env "$openclaw_bin" "$@"
}
