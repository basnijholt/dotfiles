#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/sync-uv.sh"
shell_bin=$(dirname "$(command -v bash)")
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

bin_dir="$test_root/bin"
dotbins_shell="$test_root/dotbins-shell.sh"
log="$test_root/commands.log"
mkdir -p "$bin_dir"

cat >"$dotbins_shell" <<'SHELL'
export PATH="${SYNC_UV_TEST_BIN:?}:$PATH"
SHELL

cat >"$bin_dir/uv" <<'UV'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${SYNC_UV_TEST_LOG:?}"
if [[ "${SYNC_UV_FAIL_INSTALL:-}" == 1 && "$*" == "tool install black" ]]; then
  exit 23
fi
UV
chmod +x "$bin_dir/uv"

run_sync() {
  env \
    DOTBINS_SHELL="$dotbins_shell" \
    PATH="$shell_bin:/usr/bin:/bin" \
    SYNC_UV_TEST_BIN="$bin_dir" \
    SYNC_UV_TEST_LOG="$log" \
    "$@" \
    "$shell_bin/bash" "$script" >"$test_root/output" 2>&1
}

if run_sync SYNC_UV_FAIL_INSTALL=1; then
  status=0
else
  status=$?
fi
if ! grep -Fxq 'tool install black' "$log"; then
  printf 'sync-uv could not find uv through the controlled Dotbins shell\n' >&2
  cat "$test_root/output" >&2
  exit 1
fi
if ((status == 0)); then
  printf 'sync-uv unexpectedly masked a failed parallel install\n' >&2
  exit 1
fi

: >"$log"
run_sync
grep -Fxq 'tool upgrade --all' "$log"

printf 'sync-uv tests passed\n'
