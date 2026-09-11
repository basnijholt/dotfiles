#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/cleanup-retired-pc-restic.sh"
tmp_dir="$(mktemp -d)"
fake_ssh="$tmp_dir/ssh"
log_file="$tmp_dir/ssh.log"
output_file="$tmp_dir/output"

cleanup() {
  find "$tmp_dir" -depth -delete
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file=$1
  local expected=$2

  grep -Fq -- "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_not_contains() {
  local file=$1
  local unexpected=$2

  if grep -Fq -- "$unexpected" "$file"; then
    fail "expected $file not to contain: $unexpected"
  fi
}

[[ -x "$script" ]] || fail "missing executable script: $script"

cat >"$fake_ssh" <<'FAKE_SSH'
#!/usr/bin/env bash
set -euo pipefail

payload="$(cat)"
{
  printf 'ARGS:'
  printf ' %q' "$@"
  printf '\nPAYLOAD-BEGIN\n%s\nPAYLOAD-END\n' "$payload"
} >>"$FAKE_SSH_LOG"

for arg in "$@"; do
  case "$arg" in
    nas)
      host=nas
      ;;
    pc)
      host=pc
      ;;
  esac
done

if [[ " $* " == *" sudo -S "* ]]; then
  remote_command=${!#}
  quoted_program=${remote_command#* -- bash -c }
  eval "set -- $quoted_program"
  [[ $# == 1 ]] || {
    printf 'remote command did not decode to one Bash program\n' >&2
    exit 2
  }
  bash -n <<<"$1"
  exit 0
fi

case "${host:-}" in
  nas)
    printf 'DATASET\t%s\n' 'tank/backups/pc'
    printf 'MOUNTPOINT\t%s\n' '/mnt/tank/backups/pc'
    while IFS= read -r child; do
      [[ -n "$child" ]] && printf 'CHILD\t%s\n' "$child"
    done <<<"$FAKE_NAS_CHILDREN"
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && printf 'ENTRY\t%s\n' "$entry"
    done <<<"$FAKE_NAS_ENTRIES"
    printf 'SNAPSHOT\t%s\n' 'tank/backups/pc@autosnap_2026-08-26_00:00:00_daily'
    printf 'SANOID_PRESENT\t%s\n' "${FAKE_SANOID_PRESENT:-0}"
    printf 'RESTIC_USER_PRESENT\t1\n'
    printf 'RESTIC_GROUP_PRESENT\t1\n'
    printf 'AUTHORIZED_KEYS_PRESENT\t1\n'
    ;;
  pc)
    printf 'RESTIC_UNIT_PRESENT\t%s\n' "${FAKE_PC_RESTIC_UNIT_PRESENT:-0}"
    ;;
  *)
    printf 'unexpected host in fake ssh invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
FAKE_SSH
chmod +x "$fake_ssh"

export FAKE_SSH_LOG="$log_file"
export FAKE_NAS_CHILDREN=$'tank/backups/pc/home\ntank/backups/pc/root\ntank/backups/pc/var'
export FAKE_NAS_ENTRIES=$'config\ndata\nindex\nkeys\nlocks\nsnapshots'
export FAKE_SANOID_PRESENT=0
export FAKE_PC_RESTIC_UNIT_PRESENT=0

# Dry-run is the default and must not send a mutating remote program.
: >"$log_file"
SSH_BIN="$fake_ssh" "$script" >"$output_file"
assert_contains "$output_file" 'DRY RUN'
assert_not_contains "$log_file" ' destroy '
assert_not_contains "$log_file" '-delete'
assert_not_contains "$log_file" 'userdel'
assert_not_contains "$log_file" 'groupdel'

# Every active Syncoid child is mandatory.
: >"$log_file"
export FAKE_NAS_CHILDREN=$'tank/backups/pc/home\ntank/backups/pc/var'
if printf 'DELETE PC RESTIC REPOSITORY\nnixos\n' |
  SSH_BIN="$fake_ssh" "$script" --execute >"$output_file" 2>&1; then
  fail 'execute accepted a missing tank/backups/pc/root dataset'
fi
assert_contains "$output_file" 'required child dataset is missing: tank/backups/pc/root'
assert_not_contains "$log_file" 'sudo -S'

# Unknown repository entries must stop cleanup before sudo is requested.
: >"$log_file"
export FAKE_NAS_CHILDREN=$'tank/backups/pc/home\ntank/backups/pc/root\ntank/backups/pc/var'
export FAKE_NAS_ENTRIES=$'config\ndata\nindex\nkeys\nlocks\nsnapshots\nunexpected'
if printf 'DELETE PC RESTIC REPOSITORY\nnixos\n' |
  SSH_BIN="$fake_ssh" "$script" --execute >"$output_file" 2>&1; then
  fail 'execute accepted an unknown Restic repository entry'
fi
assert_contains "$output_file" 'unknown top-level repository entry: unexpected'
assert_not_contains "$log_file" 'sudo -S'

# The confirmation phrase is exact, and a mismatch never reaches sudo.
: >"$log_file"
export FAKE_NAS_ENTRIES=$'config\ndata\nindex\nkeys\nlocks\nsnapshots'
if printf 'delete pc restic repository\nnixos\n' |
  SSH_BIN="$fake_ssh" "$script" --execute >"$output_file" 2>&1; then
  fail 'execute accepted an inexact confirmation phrase'
fi
assert_contains "$output_file" 'confirmation did not match; no changes made'
assert_not_contains "$log_file" 'sudo -S'

# Valid execution sends two fixed root transactions with bounded targets.
: >"$log_file"
printf 'DELETE PC RESTIC REPOSITORY\nnixos\n' |
  SSH_BIN="$fake_ssh" "$script" --execute >"$output_file" 2>&1

assert_contains "$log_file" 'tank/backups/pc'
assert_contains "$log_file" "\"\$dataset\"@*"
assert_contains "$log_file" "\"\$zfs_bin\" destroy \"\$snapshot\""
for entry in config data index keys locks snapshots; do
  assert_contains "$log_file" "$entry"
done
assert_contains "$log_file" '/root/.restic-password'
assert_contains "$log_file" '/root/.ssh/restic-backup'
assert_contains "$log_file" 'userdel'
assert_contains "$log_file" 'groupdel'
assert_contains "$log_file" 'could not list repository entries'
assert_contains "$log_file" 'could not list snapshots'
assert_contains "$log_file" 'could not query systemd unit'
assert_not_contains "$log_file" 'destroy -r'
assert_not_contains "$log_file" "destroy \"\$dataset\""
[[ $(grep -Fc 'sudo -S' "$log_file") == 2 ]] || fail 'expected one root transaction per host'
[[ $(grep -Fc 'Sudo password for nas and pc:' "$output_file") == 1 ]] || fail 'expected one sudo prompt'

printf 'PASS: cleanup-retired-pc-restic safety tests\n'
