#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-secrets.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

stub_hostname() {
  local bin_dir="$1"
  local hostname="$2"
  mkdir -p "$bin_dir"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' "$hostname" > "$bin_dir/hostname"
  chmod +x "$bin_dir/hostname"
}

create_secrets_remote() {
  local name="$1"
  local source_repo="$TEST_ROOT/source-$name"
  local bare_repo="$TEST_ROOT/secrets-$name.git"

  git init -q --initial-branch=main "$source_repo"
  git -C "$source_repo" config user.name Test
  git -C "$source_repo" config user.email test@example.com
  printf 'one\n' > "$source_repo/version"
  git -C "$source_repo" add version
  git -C "$source_repo" commit -qm initial
  git clone -q --bare "$source_repo" "$bare_repo" >&2
  printf '%s\n' "$bare_repo"
}

test_unapproved_host_skips_without_git_contact() {
  local home="$TEST_ROOT/unapproved"
  mkdir -p "$home/bin" "$home/dotfiles"
  stub_hostname "$home/bin" "other-host"
  cat > "$home/bin/git" <<'EOF'
#!/usr/bin/env bash
echo "git must not run" >&2
exit 99
EOF
  chmod +x "$home/bin/git"

  PATH="$home/bin:$PATH" DOTFILES_ROOT="$home/dotfiles" "$SYNC_SCRIPT"

  [[ ! -e "$home/dotfiles/secrets" ]] || fail "unapproved host created secrets checkout"
}

test_approved_host_clones_main() {
  local remote home
  remote="$(create_secrets_remote clone)"
  home="$TEST_ROOT/clone"
  stub_hostname "$home/bin" "pc"
  mkdir -p "$home/dotfiles"

  PATH="$home/bin:$PATH" DOTFILES_ROOT="$home/dotfiles" \
    SECRETS_REPO_URL="$remote" "$SYNC_SCRIPT"

  [[ "$(cat "$home/dotfiles/secrets/version")" == "one" ]] || fail "main was not cloned"
  [[ "$(git -C "$home/dotfiles/secrets" branch --show-current)" == "main" ]] || fail "checkout is not on main"
}

test_existing_checkout_fast_forwards_to_latest_main() {
  local remote home
  remote="$(create_secrets_remote update)"
  home="$TEST_ROOT/update"
  stub_hostname "$home/bin" "basnijholt-macbook-pro"
  mkdir -p "$home/dotfiles"

  git clone -q --branch main "$remote" "$home/dotfiles/secrets"
  printf 'two\n' > "$TEST_ROOT/source-update/version"
  git -C "$TEST_ROOT/source-update" add version
  git -C "$TEST_ROOT/source-update" commit -qm second
  git -C "$TEST_ROOT/source-update" push -q "$remote" main

  PATH="$home/bin:$PATH" DOTFILES_ROOT="$home/dotfiles" \
    SECRETS_REPO_URL="$remote" "$SYNC_SCRIPT"

  [[ "$(cat "$home/dotfiles/secrets/version")" == "two" ]] || fail "checkout did not update to latest main"
}

test_plain_directory_inside_git_repo_is_rejected() {
  local home="$TEST_ROOT/plain-directory"
  stub_hostname "$home/bin" "basnijholt-macbook-pro-2"
  mkdir -p "$home/dotfiles/secrets"
  git init -q --initial-branch=main "$home/dotfiles"

  if PATH="$home/bin:$PATH" DOTFILES_ROOT="$home/dotfiles" \
      SECRETS_REPO_URL="$TEST_ROOT/unused.git" "$SYNC_SCRIPT" \
      >"$home/output" 2>&1; then
    fail "plain secrets directory was accepted as a Git checkout"
  fi
  grep -q 'Secrets path is not a Git checkout' "$home/output" \
    || fail "plain secrets directory failed for wrong reason"
}

test_unapproved_host_skips_without_git_contact
test_approved_host_clones_main
test_existing_checkout_fast_forwards_to_latest_main
test_plain_directory_inside_git_repo_is_rejected
echo "sync-secrets tests passed"
