#!/usr/bin/env bash
# Git credential helper for git.nijho.lt using GITEA_TOKEN
action="${1:-}"
[ "$action" = "get" ] || exit 0

input="$(cat)"
printf '%s\n' "$input" | grep -q '^host=git\.nijho\.lt$' || exit 0

# Load token from the agenix-managed agent tooling env if not already set.
if [ -z "${GITEA_TOKEN:-}" ]; then
  tooling_env="/run/agenix/agent-tooling-env"
  if [ -r "$tooling_env" ]; then
    token_line="$(grep -m1 '^GITEA_TOKEN=' "$tooling_env" || true)"
    if [ -n "$token_line" ]; then
      GITEA_TOKEN="${token_line#GITEA_TOKEN=}"
      GITEA_TOKEN="${GITEA_TOKEN%$'\r'}"
      # Trim optional single/double quotes around the value.
      case "$GITEA_TOKEN" in
        \"*\")
          GITEA_TOKEN="${GITEA_TOKEN#\"}"
          GITEA_TOKEN="${GITEA_TOKEN%\"}"
          ;;
        \'*\')
          GITEA_TOKEN="${GITEA_TOKEN#\'}"
          GITEA_TOKEN="${GITEA_TOKEN%\'}"
          ;;
      esac
    fi
  fi
fi

[ -n "${GITEA_TOKEN:-}" ] || exit 0

printf 'protocol=https\n'
printf 'host=git.nijho.lt\n'
printf 'username=basnijholt\n'
printf 'password=%s\n' "$GITEA_TOKEN"
