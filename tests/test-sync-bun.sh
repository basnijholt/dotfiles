#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/sync-bun.sh"
shell_bin=$(dirname "$(command -v bash)")
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

bun_install="$test_root/bun"
command_bin="$test_root/commands"
dotbins_shell="$test_root/dotbins-shell.sh"
node_pty_dir="$test_root/hoisted/node-pty"
t3_dir="$bun_install/install/global/node_modules/t3"
log="$test_root/commands.log"
mkdir -p "$bun_install/bin" "$command_bin" "$node_pty_dir" "$t3_dir"
touch "$node_pty_dir/package.json"

cat >"$dotbins_shell" <<'SHELL'
export PATH="${SYNC_BUN_TEST_COMMAND_BIN:?}:$PATH"
export SYNC_BUN_DOTBINS_SOURCED=1
SHELL

cat >"$bun_install/bin/bun" <<'BUN'
#!/usr/bin/env bash
set -euo pipefail

[[ "${SYNC_BUN_DOTBINS_SOURCED:-}" == 1 ]]
printf 'bun %s\n' "$*" >>"${SYNC_BUN_TEST_LOG:?}"
if [[ "${SYNC_BUN_FAIL_INSTALL:-}" == 1 ]]; then
  exit 23
fi
BUN

cat >"$command_bin/node" <<'NODE'
#!/usr/bin/env bash
set -euo pipefail

printf 'node %s cwd=%s\n' "$*" "$PWD" >>"${SYNC_BUN_TEST_LOG:?}"
printf '%s\n' "${SYNC_BUN_NODE_PTY_PACKAGE:?}"
NODE

cat >"$bun_install/bin/node-gyp" <<'NODE_GYP'
#!/usr/bin/env bash
set -euo pipefail

printf 'node-gyp %s cwd=%s\n' "$*" "$PWD" >>"${SYNC_BUN_TEST_LOG:?}"
if [[ "${SYNC_BUN_FAIL_REBUILD:-}" == 1 ]]; then
  exit 24
fi
NODE_GYP
chmod +x "$bun_install/bin/bun" "$command_bin/node" "$bun_install/bin/node-gyp"

run_sync() {
  env \
    BUN_INSTALL="$bun_install" \
    DOTBINS_SHELL="$dotbins_shell" \
    PATH="$shell_bin:/usr/bin:/bin" \
    SYNC_BUN_TEST_COMMAND_BIN="$command_bin" \
    SYNC_BUN_NODE_PTY_PACKAGE="$node_pty_dir/package.json" \
    SYNC_BUN_TEST_LOG="$log" \
    "$@" \
    "$shell_bin/bash" "$script" >"$test_root/output" 2>&1
}

if ! run_sync; then
  printf 'sync-bun did not rebuild node-pty from the Node-resolved directory\n' >&2
  exit 1
fi
grep -Fxq "node-gyp rebuild cwd=$node_pty_dir" "$log"
if ! grep -Fxq "node -p require.resolve(\"node-pty/package.json\") cwd=$t3_dir" "$log"; then
  printf 'sync-bun did not resolve node-pty relative to T3 global modules\n' >&2
  exit 1
fi

: >"$log"
if run_sync SYNC_BUN_FAIL_INSTALL=1; then
  printf 'sync-bun unexpectedly masked a package install failure\n' >&2
  exit 1
fi

: >"$log"
if run_sync SYNC_BUN_FAIL_REBUILD=1; then
  printf 'sync-bun unexpectedly masked a node-gyp rebuild failure\n' >&2
  exit 1
fi

printf 'sync-bun tests passed\n'
