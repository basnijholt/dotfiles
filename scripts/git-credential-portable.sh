#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
input="$(cat)"

field() {
  printf '%s\n' "$input" | sed -n "s/^$1=//p" | head -n 1
}

load_gitea_token() {
  if [ -n "${GITEA_TOKEN:-}" ]; then
    printf '%s\n' "$GITEA_TOKEN"
    return 0
  fi

  local tooling_env="/run/agenix/agent-tooling-env"
  [ -r "$tooling_env" ] || return 1

  local token_line
  token_line="$(grep -m1 '^GITEA_TOKEN=' "$tooling_env" || true)"
  [ -n "$token_line" ] || return 1

  local token="${token_line#GITEA_TOKEN=}"
  token="${token%$'\r'}"

  case "$token" in
    \"*\")
      token="${token#\"}"
      token="${token%\"}"
      ;;
    \'*\')
      token="${token#\'}"
      token="${token%\'}"
      ;;
  esac

  [ -n "$token" ] || return 1
  printf '%s\n' "$token"
}

host="$(field host)"

if [ "$host" = "git.nijho.lt" ]; then
  [ "$action" = "get" ] || exit 0

  token="$(load_gitea_token)" || exit 0

  printf 'protocol=https\n'
  printf 'host=git.nijho.lt\n'
  printf 'username=basnijholt\n'
  printf 'password=%s\n' "$token"
  exit 0
fi

case "$host" in
  github.com | gist.github.com)
    if command -v gh >/dev/null 2>&1; then
      printf '%s' "$input" | gh auth git-credential "$action" && exit 0
    fi
    ;;
esac

if command -v git-credential-manager >/dev/null 2>&1; then
  printf '%s' "$input" | git-credential-manager "$action" && exit 0
fi

exit 0
