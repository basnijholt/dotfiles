#!/usr/bin/env bash

set -euo pipefail

readonly NAS_DATASET='tank/backups/pc'
readonly NAS_ROOT='/mnt/tank/backups/pc'
readonly CONFIRMATION='DELETE PC RESTIC REPOSITORY'
readonly -a REQUIRED_CHILDREN=(
  'tank/backups/pc/home'
  'tank/backups/pc/root'
  'tank/backups/pc/var'
)
readonly -a PC_CREDENTIALS=(
  '/root/.restic-password'
  '/root/.ssh/restic-backup'
  '/root/.ssh/restic-backup.pub'
)

SSH_BIN=${SSH_BIN:-ssh}
nas_host=nas
pc_host=pc
execute=false
readonly -a ssh_options=(
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o ServerAliveInterval=5
  -o ServerAliveCountMax=1
)

usage() {
  cat <<'USAGE'
Usage: cleanup-retired-pc-restic.sh [--execute] [--nas-host HOST] [--pc-host HOST]

Validate and remove the retired PC Restic repository without touching the
active Syncoid child datasets. The default is a read-only dry run.

Options:
  --execute        Perform cleanup after exact confirmation and one sudo prompt
  --nas-host HOST  SSH host for the NAS (default: nas)
  --pc-host HOST   SSH host for the PC (default: pc)
  -h, --help       Show this help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

validate_host() {
  local host=$1

  [[ -n "$host" ]] || die 'SSH host cannot be empty'
  [[ "$host" != -* ]] || die "SSH host cannot begin with '-': $host"
  [[ "$host" =~ ^[[:alnum:]_.:@-]+$ ]] || die "SSH host contains unsupported characters: $host"
}

while (($#)); do
  case "$1" in
    --execute)
      execute=true
      shift
      ;;
    --nas-host)
      (($# >= 2)) || die '--nas-host requires a value'
      nas_host=$2
      shift 2
      ;;
    --pc-host)
      (($# >= 2)) || die '--pc-host requires a value'
      pc_host=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

validate_host "$nas_host"
validate_host "$pc_host"

read_nas_state() {
  "$SSH_BIN" "${ssh_options[@]}" "$nas_host" 'bash -s' <<'REMOTE'
set -euo pipefail

dataset='tank/backups/pc'
repo_root='/mnt/tank/backups/pc'
zfs_bin="$(command -v zfs)"
find_bin="$(command -v find)"

"$zfs_bin" list -H -t filesystem -o name "$dataset" >/dev/null
printf 'DATASET\t%s\n' "$dataset"
printf 'MOUNTPOINT\t%s\n' "$("$zfs_bin" get -H -o value mountpoint "$dataset")"

child_names="$("$zfs_bin" list -H -r -d 1 -t filesystem -o name "$dataset")" || {
  printf 'could not list child datasets\n' >&2
  exit 1
}
while IFS= read -r child; do
  [[ -n "$child" ]] || continue
  [[ "$child" == "$dataset" ]] || printf 'CHILD\t%s\n' "$child"
done <<<"$child_names"

[[ -d "$repo_root" ]]
repository_entries="$("$find_bin" "$repo_root" -xdev -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort)" || {
  printf 'could not list repository entries\n' >&2
  exit 1
}
while IFS= read -r entry; do
  [[ -n "$entry" ]] || continue
  printf 'ENTRY\t%s\n' "$entry"
done <<<"$repository_entries"

snapshot_names="$("$zfs_bin" list -H -r -t snapshot -o name -s creation "$dataset")" || {
  printf 'could not list snapshots\n' >&2
  exit 1
}
while IFS= read -r snapshot; do
  [[ -n "$snapshot" ]] || continue
  case "$snapshot" in
    "$dataset"@*) printf 'SNAPSHOT\t%s\n' "$snapshot" ;;
  esac
done <<<"$snapshot_names"

if grep -Eq '^[[:space:]]*\[tank/backups/pc\][[:space:]]*$' /etc/sanoid/sanoid.conf; then
  printf 'SANOID_PRESENT\t1\n'
else
  printf 'SANOID_PRESENT\t0\n'
fi

if getent passwd restic >/dev/null; then
  printf 'RESTIC_USER_PRESENT\t1\n'
else
  printf 'RESTIC_USER_PRESENT\t0\n'
fi
if getent group restic >/dev/null; then
  printf 'RESTIC_GROUP_PRESENT\t1\n'
else
  printf 'RESTIC_GROUP_PRESENT\t0\n'
fi
if [[ -e /mnt/tank/backups/.ssh/authorized_keys || -L /mnt/tank/backups/.ssh/authorized_keys ]]; then
  printf 'AUTHORIZED_KEYS_PRESENT\t1\n'
else
  printf 'AUTHORIZED_KEYS_PRESENT\t0\n'
fi
REMOTE
}

read_pc_state() {
  "$SSH_BIN" "${ssh_options[@]}" "$pc_host" 'bash -s' <<'REMOTE'
set -euo pipefail

systemctl_bin="$(command -v systemctl)"
unit_present=0
for unit in restic-backups-truenas.service restic-backups-truenas.timer; do
  load_state="$("$systemctl_bin" show --property=LoadState --value "$unit" 2>/dev/null)" || {
    printf 'could not query systemd unit: %s\n' "$unit" >&2
    exit 1
  }
  if [[ -n "$load_state" && "$load_state" != 'not-found' ]]; then
    unit_present=1
  fi
done
printf 'RESTIC_UNIT_PRESENT\t%s\n' "$unit_present"
REMOTE
}

printf 'Checking %s and %s...\n' "$nas_host" "$pc_host"
nas_state="$(read_nas_state)" || die "could not inspect NAS host: $nas_host"
pc_state="$(read_pc_state)" || die "could not inspect PC host: $pc_host"

declare -A children=()
declare -A entries=()
declare -a parent_snapshots=()
dataset=''
mountpoint=''
sanoid_present=''
restic_user_present=''
restic_group_present=''
authorized_keys_present=''

while IFS=$'\t' read -r key value extra; do
  [[ -n "$key" && -n "$value" && -z "${extra:-}" ]] || die 'NAS returned malformed preflight data'
  case "$key" in
    DATASET) dataset=$value ;;
    MOUNTPOINT) mountpoint=$value ;;
    CHILD) children["$value"]=1 ;;
    ENTRY) entries["$value"]=1 ;;
    SNAPSHOT) parent_snapshots+=("$value") ;;
    SANOID_PRESENT) sanoid_present=$value ;;
    RESTIC_USER_PRESENT) restic_user_present=$value ;;
    RESTIC_GROUP_PRESENT) restic_group_present=$value ;;
    AUTHORIZED_KEYS_PRESENT) authorized_keys_present=$value ;;
    *) die "NAS returned unknown preflight key: $key" ;;
  esac
done <<<"$nas_state"

[[ "$dataset" == "$NAS_DATASET" ]] || die "unexpected NAS dataset: ${dataset:-missing}"
[[ "$mountpoint" == "$NAS_ROOT" ]] || die "unexpected NAS mountpoint: ${mountpoint:-missing}"
[[ "$sanoid_present" == 0 ]] || die 'deployed Sanoid config still contains [tank/backups/pc]'
[[ "$restic_user_present" =~ ^[01]$ ]] || die 'NAS did not report Restic user state'
[[ "$restic_group_present" =~ ^[01]$ ]] || die 'NAS did not report Restic group state'
[[ "$authorized_keys_present" =~ ^[01]$ ]] || die 'NAS did not report Restic SSH access state'

for child in "${REQUIRED_CHILDREN[@]}"; do
  [[ ${children["$child"]:-} == 1 ]] || die "required child dataset is missing: $child"
done

for entry in "${!entries[@]}"; do
  case "$entry" in
    config | data | index | keys | locks | snapshots) ;;
    *) die "unknown top-level repository entry: $entry" ;;
  esac
done

for snapshot in "${parent_snapshots[@]}"; do
  [[ "$snapshot" == "$NAS_DATASET"@* ]] || die "unexpected parent snapshot name: $snapshot"
done

restic_unit_present=''
while IFS=$'\t' read -r key value extra; do
  [[ -n "$key" && -n "$value" && -z "${extra:-}" ]] || die 'PC returned malformed preflight data'
  case "$key" in
    RESTIC_UNIT_PRESENT) restic_unit_present=$value ;;
    *) die "PC returned unknown preflight key: $key" ;;
  esac
done <<<"$pc_state"
[[ "$restic_unit_present" == 0 ]] || die 'PC Restic systemd unit is still loaded'

printf 'Preflight passed: %s active child datasets are protected.\n' "${#REQUIRED_CHILDREN[@]}"
printf 'NAS cleanup scope: %s repository entries, %s parent snapshots, Restic SSH account/access.\n' \
  "${#entries[@]}" "${#parent_snapshots[@]}"
printf 'PC cleanup scope:'
printf ' %s' "${PC_CREDENTIALS[@]}"
printf '\n'

if [[ "$execute" == false ]]; then
  printf 'DRY RUN: no changes made. Re-run with --execute after reviewing this scope.\n'
  exit 0
fi

printf 'Type %s to continue: ' "$CONFIRMATION" >&2
IFS= read -r confirmation
[[ "$confirmation" == "$CONFIRMATION" ]] || die 'confirmation did not match; no changes made'

printf 'Sudo password for %s and %s: ' "$nas_host" "$pc_host" >&2
IFS= read -rs sudo_password
printf '\n' >&2
[[ -n "$sudo_password" ]] || die 'sudo password cannot be empty'
trap 'unset sudo_password' EXIT

shell_quote() {
  local value=$1
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

run_root_transaction() {
  local host=$1
  local program=$2
  local remote_command

  remote_command="sudo -S -p '' -- bash -c $(shell_quote "$program")"
  printf '%s\n' "$sudo_password" |
    "$SSH_BIN" "${ssh_options[@]}" "$host" "$remote_command"
}

nas_cleanup_program() {
  cat <<'REMOTE'
set -euo pipefail

die() {
  printf 'NAS cleanup refused: %s\n' "$*" >&2
  exit 1
}

dataset='tank/backups/pc'
repo_root='/mnt/tank/backups/pc'
zfs_bin="$(command -v zfs)"
find_bin="$(command -v find)"
mountpoint_bin="$(command -v mountpoint)"

for child in tank/backups/pc/home tank/backups/pc/root tank/backups/pc/var; do
  "$zfs_bin" list -H -t filesystem -o name "$child" >/dev/null || die "missing required child dataset: $child"
done

actual_mountpoint="$("$zfs_bin" get -H -o value mountpoint "$dataset")"
[[ "$actual_mountpoint" == "$repo_root" ]] || die "unexpected mountpoint: $actual_mountpoint"
if grep -Eq '^[[:space:]]*\[tank/backups/pc\][[:space:]]*$' /etc/sanoid/sanoid.conf; then
  die 'deployed Sanoid policy still snapshots the retired repository'
fi

repository_entries="$("$find_bin" "$repo_root" -xdev -mindepth 1 -maxdepth 1 -printf '%f\n')" ||
  die 'could not list repository entries'
while IFS= read -r entry; do
  [[ -n "$entry" ]] || continue
  case "$entry" in
    config | data | index | keys | locks | snapshots) ;;
    *) die "unknown top-level repository entry: $entry" ;;
  esac
done <<<"$repository_entries"

snapshot_names="$("$zfs_bin" list -H -r -t snapshot -o name -s creation "$dataset")" ||
  die 'could not list snapshots'
while IFS= read -r snapshot; do
  [[ -n "$snapshot" ]] || continue
  case "$snapshot" in
    "$dataset"@*)
      printf 'Destroying parent snapshot %s\n' "$snapshot"
      "$zfs_bin" destroy "$snapshot"
      ;;
    "$dataset"/*) ;;
    *) die "unexpected snapshot name: $snapshot" ;;
  esac
done <<<"$snapshot_names"

for entry in config data index keys locks snapshots; do
  target="$repo_root/$entry"
  if [[ -e "$target" || -L "$target" ]]; then
    "$mountpoint_bin" -q "$target" && die "refusing mounted repository entry: $target"
    printf 'Removing repository entry %s\n' "$target"
    "$find_bin" "$target" -xdev -depth -delete
  fi
done

authorized_keys='/mnt/tank/backups/.ssh/authorized_keys'
if [[ -e "$authorized_keys" || -L "$authorized_keys" ]]; then
  printf 'Removing retired Restic SSH authorization\n'
  "$find_bin" "$authorized_keys" -xdev -depth -delete
fi
rmdir --ignore-fail-on-non-empty /mnt/tank/backups/.ssh 2>/dev/null || true

if getent passwd restic >/dev/null; then
  userdel restic
fi
if getent group restic >/dev/null; then
  groupdel restic
fi

for child in tank/backups/pc/home tank/backups/pc/root tank/backups/pc/var; do
  "$zfs_bin" list -H -t filesystem -o name "$child" >/dev/null || die "protected child disappeared: $child"
done
remaining_snapshot_names="$("$zfs_bin" list -H -r -t snapshot -o name "$dataset")" ||
  die 'could not list snapshots after cleanup'
while IFS= read -r snapshot; do
  [[ -n "$snapshot" ]] || continue
  case "$snapshot" in
    "$dataset"@*) die "parent snapshot remains: $snapshot" ;;
  esac
done <<<"$remaining_snapshot_names"
for entry in config data index keys locks snapshots; do
  [[ ! -e "$repo_root/$entry" && ! -L "$repo_root/$entry" ]] || die "repository entry remains: $entry"
done
getent passwd restic >/dev/null && die 'Restic user remains'
getent group restic >/dev/null && die 'Restic group remains'

printf 'NAS cleanup verified; Syncoid child datasets remain.\n'
REMOTE
}

pc_cleanup_program() {
  cat <<'REMOTE'
set -euo pipefail

die() {
  printf 'PC cleanup refused: %s\n' "$*" >&2
  exit 1
}

systemctl_bin="$(command -v systemctl)"
for unit in restic-backups-truenas.service restic-backups-truenas.timer; do
  load_state="$("$systemctl_bin" show --property=LoadState --value "$unit" 2>/dev/null)" ||
    die "could not query systemd unit: $unit"
  if [[ -n "$load_state" && "$load_state" != 'not-found' ]]; then
    die "Restic unit is still loaded: $unit"
  fi
done

find_bin="$(command -v find)"
for path in /root/.restic-password /root/.ssh/restic-backup /root/.ssh/restic-backup.pub; do
  if [[ -e "$path" || -L "$path" ]]; then
    printf 'Removing retired credential path %s\n' "$path"
    "$find_bin" "$path" -xdev -depth -delete
  fi
done
for path in /root/.restic-password /root/.ssh/restic-backup /root/.ssh/restic-backup.pub; do
  [[ ! -e "$path" && ! -L "$path" ]] || die "credential path remains: $path"
done

printf 'PC credential cleanup verified.\n'
REMOTE
}

printf 'Cleaning NAS retired Restic repository and access...\n'
run_root_transaction "$nas_host" "$(nas_cleanup_program)" || die 'NAS cleanup failed; PC credentials were not changed'

printf 'Cleaning PC retired Restic credentials...\n'
run_root_transaction "$pc_host" "$(pc_cleanup_program)" || die 'PC credential cleanup failed after NAS cleanup'

unset sudo_password
trap - EXIT
printf 'Cleanup complete. Active Syncoid child datasets were preserved and re-verified.\n'
