#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/sync-baspowers.sh"
shell_bin=$(dirname "$(command -v bash)")
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
  else
    printf '{"installed":[{"pluginId":"baspowers@baspowers-dev"}]}\n'
  fi
fi
STUB
chmod +x "$stub"
# The script puts $BUN_INSTALL/bin first on PATH, so stubs there shadow the
# real CLIs. The claude stub catches any `claude plugin` call, which would
# rewrite the tracked configs/claude/settings.json.
bun_install="$test_root/bun"
mkdir -p "$bun_install/bin"
ln -s "$stub" "$bun_install/bin/codex"
ln -s "$stub" "$bun_install/bin/claude"
ln -s "$stub" "$test_root/codex"

export BUN_INSTALL="$bun_install"
export BASPOWERS_CODEX_BIN="$test_root/codex"
export BASPOWERS_TEST_LOG="$log"

bash "$script" >"$test_root/override-output" 2>&1

expected=$(cat <<EOF
codex plugin remove baspowers@baspowers-dev
codex plugin marketplace remove baspowers-dev
codex plugin marketplace add $repo_root/submodules/baspowers
codex plugin add baspowers@baspowers-dev
codex plugin list --json
codex plugin remove ${legacy}@${legacy}-dev
codex plugin marketplace remove ${legacy}-dev
codex plugin remove ${legacy}@openai-curated
EOF
)
[[ $(cat "$log") == "$expected" ]]

: >"$log"
if ! env -u BASPOWERS_CODEX_BIN \
  BASPOWERS_TEST_LOG="$log" \
  BUN_INSTALL="$bun_install" \
  PATH="$shell_bin:/usr/bin:/bin" \
  "$shell_bin/bash" "$script" >"$test_root/bun-install-output" 2>&1; then
  printf 'sync-baspowers did not resolve Codex from BUN_INSTALL/bin\n' >&2
  exit 1
fi
[[ $(head -n 1 "$log") == 'codex plugin remove baspowers@baspowers-dev' ]]
if grep -q '^claude ' "$log"; then
  printf 'sync-baspowers ran claude plugin commands\n' >&2
  exit 1
fi

: >"$log"
touch "$test_root/missing"
export BASPOWERS_TEST_MISSING="$test_root/missing"
if bash "$script" >"$test_root/missing-output" 2>&1; then
  printf 'sync unexpectedly accepted a missing Codex plugin\n' >&2
  exit 1
fi

printf 'sync-baspowers tests passed\n'
