#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/sync-baspowers.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

stub="$test_root/codex"
state="$test_root/state"
log="$test_root/mutations.log"
claude_stub="$test_root/claude"
claude_state="$test_root/claude-state"
claude_log="$test_root/claude-mutations.log"
mkdir -p "$state" "$claude_state"
legacy='super''powers'

cat >"$stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

state=${CODEX_BASPOWERS_TEST_STATE:?}
log=${CODEX_BASPOWERS_TEST_LOG:?}
legacy='super''powers'

case "$*" in
  "plugin marketplace list --json")
    if [[ -e "$state/marketplace" ]]; then
      printf '{"marketplaces":[{"name":"baspowers-dev"}]}\n'
    else
      printf '{"marketplaces":[]}\n'
    fi
    ;;
  "plugin marketplace add "*)
    printf '%s\n' "$*" >>"$log"
    touch "$state/marketplace"
    ;;
  "plugin marketplace remove baspowers-dev")
    printf '%s\n' "$*" >>"$log"
    rm -f "$state/marketplace"
    ;;
  "plugin list --json")
    printf '{"installed":['
    sep=
    if [[ ! -e "$state/official_removed" ]]; then
      printf '{"pluginId":"%s@openai-curated"}' "$legacy"
      sep=,
    fi
    if [[ -e "$state/local" ]]; then
      printf '%s{"pluginId":"baspowers@baspowers-dev"}' "$sep"
    fi
    printf ']}\n'
    ;;
  "plugin add baspowers@baspowers-dev")
    printf '%s\n' "$*" >>"$log"
    if [[ -e "$state/fail_local_add" ]]; then
      exit 1
    fi
    touch "$state/local"
    ;;
  "plugin add ${legacy}@openai-curated")
    printf '%s\n' "$*" >>"$log"
    rm -f "$state/official_removed"
    ;;
  "plugin remove ${legacy}@openai-curated")
    printf '%s\n' "$*" >>"$log"
    touch "$state/official_removed"
    ;;
  "plugin remove baspowers@baspowers-dev")
    printf '%s\n' "$*" >>"$log"
    rm -f "$state/local"
    ;;
  *)
    printf 'unexpected codex invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
STUB
chmod +x "$stub"

cat >"$claude_stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

state=${CODEX_BASPOWERS_CLAUDE_TEST_STATE:?}
log=${CODEX_BASPOWERS_CLAUDE_TEST_LOG:?}
legacy='super''powers'

case "$*" in
  "plugin marketplace list --json")
    if [[ -e "$state/marketplace" ]]; then
      printf '[{"name":"baspowers-dev"}]\n'
    else
      printf '[]\n'
    fi
    ;;
  "plugin marketplace add "*)
    printf '%s\n' "$*" >>"$log"
    touch "$state/marketplace"
    ;;
  "plugin marketplace remove baspowers-dev")
    printf '%s\n' "$*" >>"$log"
    rm -f "$state/marketplace"
    ;;
  "plugin list --json")
    printf '['
    sep=
    if [[ ! -e "$state/official_removed" ]]; then
      printf '{"id":"%s@claude-plugins-official"}' "$legacy"
      sep=,
    fi
    if [[ -e "$state/local" ]]; then
      printf '%s{"id":"baspowers@baspowers-dev"}' "$sep"
    fi
    printf ']\n'
    ;;
  "plugin install baspowers@baspowers-dev")
    printf '%s\n' "$*" >>"$log"
    if [[ -e "$state/fail_local_add" ]]; then
      exit 1
    fi
    touch "$state/local"
    ;;
  "plugin install ${legacy}@claude-plugins-official")
    printf '%s\n' "$*" >>"$log"
    rm -f "$state/official_removed"
    ;;
  "plugin uninstall ${legacy}@claude-plugins-official")
    printf '%s\n' "$*" >>"$log"
    touch "$state/official_removed"
    ;;
  "plugin uninstall baspowers@baspowers-dev")
    printf '%s\n' "$*" >>"$log"
    rm -f "$state/local"
    ;;
  *)
    printf 'unexpected claude invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
STUB
chmod +x "$claude_stub"

export CODEX_BASPOWERS_CODEX_BIN="$stub"
export CODEX_BASPOWERS_TEST_STATE="$state"
export CODEX_BASPOWERS_TEST_LOG="$log"
export CODEX_BASPOWERS_CLAUDE_BIN="$claude_stub"
export CODEX_BASPOWERS_CLAUDE_TEST_STATE="$claude_state"
export CODEX_BASPOWERS_CLAUDE_TEST_LOG="$claude_log"

bash "$script"

expected=$(cat <<EOF
plugin marketplace add $repo_root/submodules/baspowers
plugin add baspowers@baspowers-dev
plugin remove ${legacy}@openai-curated
EOF
)
actual=$(cat "$log")
[[ "$actual" == "$expected" ]]
claude_expected=$(cat <<EOF
plugin marketplace add $repo_root/submodules/baspowers
plugin install baspowers@baspowers-dev
plugin uninstall ${legacy}@claude-plugins-official
EOF
)
claude_actual=$(cat "$claude_log")
[[ "$claude_actual" == "$claude_expected" ]]

: >"$log"
: >"$claude_log"
bash "$script"
expected=$(cat <<EOF
plugin add ${legacy}@openai-curated
plugin remove baspowers@baspowers-dev
plugin marketplace remove baspowers-dev
plugin marketplace add $repo_root/submodules/baspowers
plugin add baspowers@baspowers-dev
plugin remove ${legacy}@openai-curated
EOF
)
actual=$(cat "$log")
[[ "$actual" == "$expected" ]]
claude_expected=$(cat <<EOF
plugin install ${legacy}@claude-plugins-official
plugin uninstall baspowers@baspowers-dev
plugin marketplace remove baspowers-dev
plugin marketplace add $repo_root/submodules/baspowers
plugin install baspowers@baspowers-dev
plugin uninstall ${legacy}@claude-plugins-official
EOF
)
claude_actual=$(cat "$claude_log")
[[ "$claude_actual" == "$claude_expected" ]]

touch "$state/fail_local_add"
if bash "$script"; then
  printf 'sync unexpectedly succeeded when local plugin add failed\n' >&2
  exit 1
fi
[[ ! -e "$state/official_removed" ]]

printf 'sync-baspowers tests passed\n'
