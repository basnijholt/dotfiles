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
  cat > "$home/bin/git" <<'EOF'
#!/usr/bin/env bash
echo "git must not run" >&2
exit 99
EOF
  chmod +x "$home/bin/git"

  PATH="$home/bin:$PATH" DOTFILES_ROOT="$home/dotfiles" \
    SYNC_SECRETS_HOSTNAME="other-host" "$SYNC_SCRIPT"

  [[ ! -e "$home/dotfiles/secrets" ]] || fail "unapproved host created secrets checkout"
}

test_approved_host_clones_main() {
  local remote home
  remote="$(create_secrets_remote clone)"
  home="$TEST_ROOT/clone"
  mkdir -p "$home/dotfiles"

  DOTFILES_ROOT="$home/dotfiles" SECRETS_REPO_URL="$remote" \
    SYNC_SECRETS_HOSTNAME="pc" "$SYNC_SCRIPT"

  [[ "$(cat "$home/dotfiles/secrets/version")" == "one" ]] || fail "main was not cloned"
  [[ "$(git -C "$home/dotfiles/secrets" branch --show-current)" == "main" ]] || fail "checkout is not on main"
}

test_existing_checkout_fast_forwards_to_latest_main() {
  local remote home
  remote="$(create_secrets_remote update)"
  home="$TEST_ROOT/update"
  mkdir -p "$home/dotfiles"

  git clone -q --branch main "$remote" "$home/dotfiles/secrets"
  printf 'two\n' > "$TEST_ROOT/source-update/version"
  git -C "$TEST_ROOT/source-update" add version
  git -C "$TEST_ROOT/source-update" commit -qm second
  git -C "$TEST_ROOT/source-update" push -q "$remote" main

  DOTFILES_ROOT="$home/dotfiles" SECRETS_REPO_URL="$remote" \
    SYNC_SECRETS_HOSTNAME="basnijholt-macbook-pro" "$SYNC_SCRIPT"

  [[ "$(cat "$home/dotfiles/secrets/version")" == "two" ]] || fail "checkout did not update to latest main"
}

test_unapproved_host_skips_without_git_contact
test_approved_host_clones_main
test_existing_checkout_fast_forwards_to_latest_main
echo "sync-secrets tests passed"
