# Fleet Install Repair Design

## Goal

Make `scripts/sync-dotfiles.sh install` succeed on every reachable fleet host while preserving host-local work, eliminating avoidable SSH transport dependencies, and reporting real failures.

## Current failure domains

1. Public GitHub repositories still use SSH URLs on hosts without trusted host keys or private keys.
2. `sync-bun.sh` and `sync-baspowers.sh` assume interactive-shell PATH setup, so `node-gyp`, `codex`, and `claude` are invisible over noninteractive SSH.
3. `sync-bun.sh` assumes `node-pty` is nested below T3, but Bun may hoist it to the global package root.
4. `sync-uv.sh` and `sync-bun.sh` can hide earlier command failures.
5. The generic secrets installer treats workstation-only secrets as mandatory on `pi4`, although `pi4` only needs its existing ZFS-unlock material.
6. `gce-vm` and `mindroom` have failed autostash reapplications; their local changes must remain uncommitted.
7. `nix-cache` has a corrupt `mydotbins` object database; `pc` has root-owned UV/Codex state; `nas` has an obsolete broken UV tool.
8. `pi3` is offline at the network layer and cannot be repaired remotely until it is reachable.

## Repository changes

### Git transport

Use HTTPS for every public GitHub submodule in `.gitmodules`. Keep private secrets handling unchanged. `git submodule sync --recursive` remains before updates so existing cached URLs migrate automatically.

### Tool installers

- `sync-uv.sh` and `sync-bun.sh` fail immediately on errors.
- `sync-bun.sh` exports `${BUN_INSTALL:-$HOME/.bun}/bin` before invoking Bun-installed tools.
- `sync-bun.sh` asks Node to resolve `node-pty/package.json` relative to the installed T3 package, supporting nested and hoisted layouts, then invokes the explicit Bun-installed `node-gyp`.
- `sync-baspowers.sh` exports the same Bun bin directory before resolving default Codex and Claude executables.
- Dotbot exposes stdout and stderr for each synchronization command.

### Pi 4 secrets

`sync-secrets.sh` continues updating the private checkout on `pi4`, validates the required decrypted ZFS-unlock config and key files, and preserves any existing user config. If the config target is absent, it creates a symlink to the decrypted config. It does not run the generic workstation secrets installer on `pi4`.

Required Pi 4 files are:

- `configs/zfs-unlock/config.yaml`
- `configs/zfs-unlock/frigate_key`
- `configs/zfs-unlock/photos_export_key`
- `configs/zfs-unlock/photos_key`
- `configs/zfs-unlock/stash_key`
- `configs/zfs-unlock/zfs-unlock-receiver`

## Host-local repairs

- Resolve `gce-vm`'s `configs/codex/AGENTS.md` with the current upstream version and stage only that path. Do not commit or drop the retained autostash.
- Resolve `mindroom`'s `configs/claude/settings.json` by preserving the combined worktree plus `"alwaysThinkingEnabled": false`, then stage only that path. Do not commit or drop the retained autostash.
- Change the public top-level origins on `docker-lxc` and `hetzner` to HTTPS, preserving local modifications through autostash.
- Move the corrupt `nix-cache` `mydotbins` worktree and gitdir into a persistent recovery directory, then reinitialize from HTTPS and verify it with `git fsck`.
- Recover root-owned UV environments on `pc` into persistent storage and recreate desired tools as the user. Root-owned Codex temp artifacts may remain preserved when privilege is unavailable if fresh Codex and Claude plugin operations succeed; they are cleanup noise, not plugin state.
- Remove the obsolete broken `truenas-unlock` UV tool on `nas`; the desired replacement is `zfs-unlock`.
- Let the repository-wide HTTPS migration repair `hetzner-saas` and future public submodule fetches.

## Safety constraints

- Never commit on `gce-vm` or `mindroom`.
- Never discard host-local changes, retained autostashes, corrupt Git state, or inaccessible root-owned temp artifacts; preserve recoverable backups.
- Never use `git reset --hard`, force pushes, broad recursive deletion, or `git add -A`.
- Never expose secret contents in logs, tests, commits, or review descriptions.
- Do not modify `pi3` routing; report it as externally blocked until Layer-2 reachability returns.
- Keep repository changes minimal and test shell behavior through controlled command boundaries.

## Verification

1. Every new regression test is observed failing before its implementation and passing after it.
2. All shell tests, syntax checks, and `git diff --check` pass.
3. A normal PR receives review; valid findings are addressed before merge.
4. The fleet install is rerun after central changes land.
5. Each reachable host is reported independently, with `pi3` explicitly identified as an external availability blocker if still offline.
