#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/sync-codex-superpowers.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

stub="$test_root/codex"
state="$test_root/state"
log="$test_root/mutations.log"
mkdir -p "$state"

cat >"$stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

state=${CODEX_SUPERPOWERS_TEST_STATE:?}
log=${CODEX_SUPERPOWERS_TEST_LOG:?}

case "$*" in
  "plugin marketplace list --json")
    if [[ -e "$state/marketplace" ]]; then
      printf '{"marketplaces":[{"name":"superpowers-dev"}]}\n'
    else
      printf '{"marketplaces":[]}\n'
    fi
    ;;
  "plugin marketplace add "*)
    printf '%s\n' "$*" >>"$log"
    touch "$state/marketplace"
    ;;
  "plugin marketplace remove superpowers-dev")
    printf '%s\n' "$*" >>"$log"
    rm -f "$state/marketplace"
    ;;
  "plugin list --json")
    printf '{"installed":['
    sep=
    if [[ ! -e "$state/official_removed" ]]; then
      printf '{"pluginId":"superpowers@openai-curated"}'
      sep=,
    fi
    if [[ -e "$state/local" ]]; then
      printf '%s{"pluginId":"superpowers@superpowers-dev"}' "$sep"
    fi
    printf ']}\n'
    ;;
  "plugin add superpowers@superpowers-dev")
    printf '%s\n' "$*" >>"$log"
    touch "$state/local"
    ;;
  "plugin remove superpowers@openai-curated")
    printf '%s\n' "$*" >>"$log"
    touch "$state/official_removed"
    ;;
  "plugin remove superpowers@superpowers-dev")
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

export CODEX_SUPERPOWERS_CODEX_BIN="$stub"
export CODEX_SUPERPOWERS_TEST_STATE="$state"
export CODEX_SUPERPOWERS_TEST_LOG="$log"

bash "$script"

expected=$(cat <<EOF
plugin marketplace add $repo_root/submodules/superpowers
plugin add superpowers@superpowers-dev
plugin remove superpowers@openai-curated
EOF
)
actual=$(cat "$log")
[[ "$actual" == "$expected" ]]

: >"$log"
bash "$script"
expected=$(cat <<EOF
plugin remove superpowers@superpowers-dev
plugin marketplace remove superpowers-dev
plugin marketplace add $repo_root/submodules/superpowers
plugin add superpowers@superpowers-dev
EOF
)
actual=$(cat "$log")
[[ "$actual" == "$expected" ]]

printf 'sync-codex-superpowers tests passed\n'
