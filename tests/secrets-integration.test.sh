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
sync = "- command: bash scripts/sync-secrets.sh\n    stdout: true"
assert sync in config, "Dotbot does not run the self-contained secrets sync command"
assert "secrets/install" not in config, "Dotbot must not run secrets installer independently"
assert config.index(sync) < config.index("git submodule update --init --recursive"), (
    "secrets sync must happen before recursive submodule update"
)
PY

echo "secrets integration tests passed"
