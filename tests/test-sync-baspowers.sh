#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/sync-baspowers.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

log="$test_root/commands.log"
stub="$test_root/plugin-cli"
legacy='super''powers'

cat >"$stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

printf '%s %s\n' "$(basename "$0")" "$*" >>"${BASPOWERS_TEST_LOG:?}"

if [[ "$*" == "plugin list --json" ]]; then
  if [[ -e "${BASPOWERS_TEST_MISSING:-}" ]]; then
    printf '[]\n'
  elif [[ $(basename "$0") == codex ]]; then
    printf '{"installed":[{"pluginId":"baspowers@baspowers-dev"}]}\n'
  else
    printf '[{"id":"baspowers@baspowers-dev"}]\n'
  fi
fi
STUB
chmod +x "$stub"
ln -s "$stub" "$test_root/codex"
ln -s "$stub" "$test_root/claude"

export BASPOWERS_CODEX_BIN="$test_root/codex"
export BASPOWERS_CLAUDE_BIN="$test_root/claude"
export BASPOWERS_TEST_LOG="$log"

bash "$script"

expected=$(cat <<EOF
codex plugin remove baspowers@baspowers-dev
codex plugin marketplace remove baspowers-dev
codex plugin marketplace add $repo_root/submodules/baspowers
codex plugin add baspowers@baspowers-dev
codex plugin list --json
codex plugin remove ${legacy}@${legacy}-dev
codex plugin marketplace remove ${legacy}-dev
codex plugin remove ${legacy}@openai-curated
claude plugin uninstall baspowers@baspowers-dev
claude plugin marketplace remove baspowers-dev
claude plugin marketplace add $repo_root/submodules/baspowers
claude plugin install baspowers@baspowers-dev
claude plugin list --json
claude plugin uninstall ${legacy}@${legacy}-dev
claude plugin marketplace remove ${legacy}-dev
claude plugin uninstall ${legacy}@claude-plugins-official
EOF
)
[[ $(cat "$log") == "$expected" ]]

: >"$log"
touch "$test_root/missing"
export BASPOWERS_TEST_MISSING="$test_root/missing"
if bash "$script"; then
  printf 'sync unexpectedly accepted a missing Codex plugin\n' >&2
  exit 1
fi

printf 'sync-baspowers tests passed\n'
