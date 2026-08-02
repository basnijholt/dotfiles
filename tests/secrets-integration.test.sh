#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if git ls-files --stage secrets | grep -q '^160000 '; then
  fail "secrets is still a submodule gitlink"
fi

! git config -f .gitmodules --get-regexp '^submodule\.secrets\.' >/dev/null 2>&1 \
  || fail "secrets remains in .gitmodules"

git check-ignore -q secrets/example || fail "ordinary secrets checkout is not ignored"
grep -qx 'scripts/sync-secrets.sh' .publicignore \
  || fail "private sync script is not removed from public branch"

python3 - <<'PY'
from pathlib import Path

config = Path("install.conf.yaml").read_text()
sync_and_install = (
    "- command: 'bash scripts/sync-secrets.sh && "
    "{ [ ! -f ./secrets/install ] || (echo \"SECRETS\" && ./secrets/install); }'\n"
    "    stdout: true"
)
assert sync_and_install in config, "Dotbot does not short-circuit install when secrets sync fails"
assert sum("secrets/install" in line for line in config.splitlines()) == 1, (
    "secrets install must not be a separate Dotbot command"
)
assert config.index(sync_and_install) < config.index("git submodule update --init --recursive"), (
    "secrets sync must happen before recursive submodule update"
)
PY

echo "secrets integration tests passed"
