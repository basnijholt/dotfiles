#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/sync-secrets.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

remote="$test_root/secrets-remote.git"
seed="$test_root/secrets-seed"
dotfiles_root="$test_root/dotfiles"
secrets_dir="$test_root/secrets-checkout"
config_target="$test_root/config/zfs-unlock/config.yaml"
marker="$test_root/generic-installer-ran"
output="$test_root/output"
required_files=(
  configs/zfs-unlock/config.yaml
  configs/zfs-unlock/frigate_key
  configs/zfs-unlock/photos_export_key
  configs/zfs-unlock/photos_key
  configs/zfs-unlock/stash_key
  configs/zfs-unlock/zfs-unlock-receiver
)

git init --bare --initial-branch=main "$remote" >/dev/null
git clone "$remote" "$seed" >/dev/null
(
  cd "$seed"
  git config user.email test@example.invalid
  git config user.name 'sync-secrets test'
  for required_file in "${required_files[@]}"; do
    mkdir -p "$(dirname "$required_file")"
    if [[ "$required_file" == configs/zfs-unlock/config.yaml ]]; then
      printf '%s\n' 'test-only-unlock-material' >"$required_file"
    else
      : >"$required_file"
    fi
  done
  cat >install <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail
touch "${SYNC_SECRETS_TEST_MARKER:?}"
INSTALL
  chmod +x install
  git add configs/zfs-unlock install
  git commit -m 'fixture secrets' >/dev/null
  git push origin main >/dev/null
)
git clone "$remote" "$secrets_dir" >/dev/null
mkdir -p "$dotfiles_root"
ln -s "$secrets_dir" "$dotfiles_root/secrets"

run_sync() {
  env \
    DOTFILES_ROOT="$dotfiles_root" \
    SECRETS_DIR="$secrets_dir" \
    SYNC_SECRETS_HOSTNAME=pi4 \
    SYNC_SECRETS_TEST_MARKER="$marker" \
    ZFS_UNLOCK_CONFIG_TARGET="$config_target" \
    bash "$script" >"$output" 2>&1
}

mkdir -p "$(dirname "$config_target")"
: >"$config_target"
run_sync
if [[ -e "$marker" ]]; then
  printf 'pi4 unexpectedly invoked the generic secrets installer\n' >&2
  exit 1
fi
if [[ -L "$config_target" ]]; then
  printf 'pi4 replaced an existing ZFS-unlock config target\n' >&2
  exit 1
fi

rm "$config_target"
run_sync
if [[ -e "$marker" ]]; then
  printf 'pi4 unexpectedly invoked the generic secrets installer\n' >&2
  exit 1
fi
if [[ ! -L "$config_target" || "$(readlink "$config_target")" != "$secrets_dir/configs/zfs-unlock/config.yaml" ]]; then
  printf 'pi4 did not link the absent ZFS-unlock config target\n' >&2
  exit 1
fi

rm "$config_target"
ln -s "$test_root/missing-config.yaml" "$config_target"
run_sync
if [[ ! -L "$config_target" || "$(readlink "$config_target")" != "$secrets_dir/configs/zfs-unlock/config.yaml" ]]; then
  printf 'pi4 did not repair a dangling ZFS-unlock config link\n' >&2
  exit 1
fi

rm "$secrets_dir/configs/zfs-unlock/photos_key"
if run_sync; then
  printf 'pi4 accepted a missing required ZFS-unlock key\n' >&2
  exit 1
fi
if [[ -e "$marker" ]]; then
  printf 'pi4 invoked the generic secrets installer after validation failed\n' >&2
  exit 1
fi
if grep -Fq 'test-only-unlock-material' "$output"; then
  printf 'pi4 printed secret material after validation failed\n' >&2
  exit 1
fi

printf 'sync-secrets tests passed\n'
