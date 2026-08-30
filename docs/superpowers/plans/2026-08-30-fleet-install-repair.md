# Fleet Install Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make fleet installation reliable on every reachable host without losing or committing host-local work.

**Architecture:** Harden the shared repository scripts first, merge them through review, then repair exceptional remote state and rerun the same fleet entrypoint. Public repositories use HTTPS; private secrets remain private and `pi4` receives only its ZFS-unlock-specific handling.

**Tech Stack:** Bash, Git submodules, Dotbot YAML, SSH, UV, Bun, Codex and Claude plugin CLIs.

**Spec:** `docs/superpowers/specs/2026-08-30-fleet-install-repair-design.md`

## Global Constraints

- Never commit on `gce-vm` or `mindroom`.
- Preserve host-local changes, retained autostashes, and corrupt Git state in persistent recovery locations.
- Never use `git reset --hard`, force pushes, broad recursive deletion, or `git add -A`.
- Never expose secret contents.
- Do not modify `pi3` routing while it is unreachable at Layer 2.
- Do not create branches beginning with `codex/`.
- Run `git status` before staging and verify staged paths afterward.
- Do not amend commits.

---

### Task 1: Normalize Public Submodule Transport

**Files:**
- Modify: `.gitmodules`
- Create: `tests/test-submodule-urls.sh`

**Interfaces:**
- Consumes: Git's `.gitmodules` configuration parser.
- Produces: HTTPS URLs consumed by `git submodule sync --recursive` on every host.

- [ ] **Step 1: Write the failing transport regression test**

Create a Bash test that runs `git config -f .gitmodules --get-regexp '^submodule\..*\.url$'`, fails if any value begins with `git@github.com:`, and prints `submodule URL tests passed` otherwise.

- [ ] **Step 2: Verify the transport test fails**

Run: `bash tests/test-submodule-urls.sh`

Expected: nonzero with the existing SSH-backed public submodule names.

- [ ] **Step 3: Convert verified-public GitHub URLs to HTTPS**

Use these exact repository mappings:

```text
basnijholt/backups                    https://github.com/basnijholt/backups.git
basnijholt/dotbins                    https://github.com/basnijholt/dotbins.git
basnijholt/mydotbins                  https://github.com/basnijholt/mydotbins.git
robbyrussell/oh-my-zsh                https://github.com/robbyrussell/oh-my-zsh.git
dschrempf/syncthing-resolve-conflicts https://github.com/dschrempf/syncthing-resolve-conflicts.git
ThorpeJosh/truenas-zfs-unlock         https://github.com/ThorpeJosh/truenas-zfs-unlock.git
zsh-users/zsh-autosuggestions         https://github.com/zsh-users/zsh-autosuggestions.git
zsh-users/zsh-syntax-highlighting     https://github.com/zsh-users/zsh-syntax-highlighting.git
```

- [ ] **Step 4: Verify the transport test and remote access**

Run the test, `git diff --check`, and `git ls-remote --exit-code <url> HEAD` for every changed URL. Expected: all exit zero.

- [ ] **Step 5: Commit Task 1**

Run `git status --short`, stage only `.gitmodules` and `tests/test-submodule-urls.sh`, inspect `git diff --cached`, and commit with `fix(sync): use HTTPS for public submodules`.

---

### Task 2: Harden Tool Synchronization

**Files:**
- Modify: `scripts/sync-uv.sh`
- Modify: `scripts/sync-bun.sh`
- Modify: `scripts/sync-baspowers.sh`
- Modify: `install.conf.yaml`
- Create: `tests/test-sync-uv.sh`
- Create: `tests/test-sync-bun.sh`
- Modify: `tests/test-sync-baspowers.sh`

**Interfaces:**
- Consumes: `${DOTBINS_SHELL:-$HOME/.dotbins/shell/bash.sh}`, `${BUN_INSTALL:-$HOME/.bun}`, Bun global T3 installation, and Codex/Claude CLIs.
- Produces: noninteractive installers that expose failures and resolve Bun-installed executables consistently.

- [ ] **Step 1: Write failing UV and Bun behavior tests**

The UV test must execute `sync-uv.sh` with a controlled Dotbins shell and fake `uv`, proving any failed parallel install makes the script return nonzero and the success path reaches `uv tool upgrade --all`.

The Bun test must execute `sync-bun.sh` with controlled `DOTBINS_SHELL` and `BUN_INSTALL`, prove the Bun bin directory is used, emulate Node resolving a hoisted `node-pty`, and assert `node-gyp rebuild` runs from that resolved directory. It must fail if a package install or rebuild fails.

Extend the Baspowers test with a no-override case where Codex and Claude resolve only through `${BUN_INSTALL}/bin`.

- [ ] **Step 2: Verify all new behavior tests fail for the intended missing behavior**

Run each test separately. Expected: failures identify masked errors, missing Bun PATH, or the hard-coded nested `node-pty` path—not test setup errors.

- [ ] **Step 3: Implement minimal fail-fast and PATH handling**

Add `set -euo pipefail` to UV and Bun scripts. Source `${DOTBINS_SHELL:-$HOME/.dotbins/shell/bash.sh}`. In Bun and Baspowers scripts use:

```bash
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PATH="$BUN_INSTALL/bin:$PATH"
```

Keep Baspowers' explicit `BASPOWERS_CODEX_BIN` and `BASPOWERS_CLAUDE_BIN` overrides authoritative.

- [ ] **Step 4: Resolve `node-pty` dynamically**

After installing T3 and node-gyp, resolve `node-pty/package.json` with Node relative to `$BUN_INSTALL/install/global/node_modules/t3`, take its directory, change into it, and run `"$BUN_INSTALL/bin/node-gyp" rebuild`. Fail clearly if resolution fails.

- [ ] **Step 5: Expose Dotbot command output**

Convert each synchronization shell entry in `install.conf.yaml` to mapping form with `command`, `stdout: true`, and `stderr: true`, retaining command order.

- [ ] **Step 6: Verify all installer tests**

Run all files under `tests/test-sync-*.sh`, Bash syntax checks for changed scripts/tests, and `git diff --check`. Expected: all exit zero.

- [ ] **Step 7: Commit Task 2**

Run `git status --short`, stage only Task 2 files, inspect staged paths/diff, and commit with `fix(install): harden noninteractive tool sync`.

---

### Task 3: Limit Pi 4 Secrets Installation

**Files:**
- Modify: `scripts/sync-secrets.sh`
- Create: `tests/test-sync-secrets.sh`

**Interfaces:**
- Consumes: `SYNC_SECRETS_HOSTNAME` for tests, `DOTFILES_ROOT`, optional `SECRETS_DIR`, and optional `ZFS_UNLOCK_CONFIG_TARGET`.
- Produces: generic secrets installation for workstation hosts and ZFS-unlock-only validation/linking for `pi4`.

- [ ] **Step 1: Write the failing Pi 4 secrets test**

Execute the real script with a controlled secrets checkout and Git boundary. Create the six required decrypted files, omit workstation-only files, and make the generic secrets installer write a marker if invoked. Assert `pi4` succeeds without that marker, preserves an existing config target, and creates a symlink when the target is absent. Add a missing-required-key case that returns nonzero without printing secret content.

- [ ] **Step 2: Verify the test fails for the generic installer behavior**

Run: `bash tests/test-sync-secrets.sh`

Expected: nonzero because the current script invokes the generic installer on `pi4`.

- [ ] **Step 3: Implement the Pi 4-specific path**

Allow `SYNC_SECRETS_HOSTNAME`, `SECRETS_DIR`, and `ZFS_UNLOCK_CONFIG_TARGET` overrides with production-safe defaults. After updating the checkout, validate the exact six files from the spec. Preserve an existing target; otherwise create its parent and symlink it to `configs/zfs-unlock/config.yaml`. Return without invoking `secrets/install` on `pi4`.

- [ ] **Step 4: Verify secrets behavior and full shell suite**

Run the new test, all existing shell tests, Bash syntax checks, and `git diff --check`. Expected: all exit zero and no secret contents appear.

- [ ] **Step 5: Commit Task 3**

Run `git status --short`, stage only `scripts/sync-secrets.sh` and `tests/test-sync-secrets.sh`, inspect the staged diff, and commit with `fix(secrets): limit pi4 install to zfs unlock`.

---

### Task 4: Repair Host-Local State

**Files:**
- No repository files. Mutate only explicitly identified remote Git metadata, conflict paths, ownership entries, and recovery directories.

**Interfaces:**
- Consumes: merged repository changes from Tasks 1-3.
- Produces: reachable hosts able to run the shared installer while retaining their local work.

- [ ] **Step 1: Resolve `gce-vm` without committing**

Take the current upstream version of `configs/codex/AGENTS.md`, verify conflict markers are absent, run `git diff --check` for that path, and stage only it. Confirm no merge/rebase/cherry-pick is active, retain the autostash, and do not commit.

- [ ] **Step 2: Resolve `mindroom` without committing**

Preserve the current combined `configs/claude/settings.json`, add top-level `"alwaysThinkingEnabled": false` before `effortLevel`, validate with `jq`, verify no conflict markers, and stage only that path. Retain all other changes and the autostash; do not commit.

- [ ] **Step 3: Repair public top-level origins**

On `docker-lxc` and `hetzner`, set origin to `https://github.com/basnijholt/dotfiles.git`, verify `ls-remote`, and let the shared `git pull --autostash` preserve local modifications.

- [ ] **Step 4: Rebuild corrupt `nix-cache` submodule reversibly**

Move both `submodules/mydotbins` and `.git/modules/submodules/mydotbins` into a timestamped directory under `~/dotfiles-recovery/`, set its cached URL to HTTPS, reinitialize the submodule, run `git fsck --full`, and verify HEAD equals `91e1b88bb9d47358c965c6118a33e77a56e5419d`.

- [ ] **Step 5: Repair user-owned package state**

On `pc`, list and validate every root-owned entry under `~/.local/share/uv/tools` and `~/.codex/tmp/arg0`, then use sudo to change only those entries to `basnijholt:users`. On `nas`, remove only the obsolete broken `truenas-unlock` UV tool and verify desired `zfs-unlock` installs successfully.

- [ ] **Step 6: Verify host-local invariants**

Confirm no commits were created on `gce-vm` or `mindroom`, their indexes have no unmerged entries, remote recovery backups exist, and public remotes resolve through HTTPS.

---

### Task 5: Review, Merge, and Fleet Rollout

**Files:**
- No new repository files beyond review fixes.

**Interfaces:**
- Consumes: reviewed commits from Tasks 1-3 and repaired host state from Task 4.
- Produces: merged `main` and a verified fleet install summary.

- [ ] **Step 1: Run final repository verification**

Run every `tests/test-*.sh`, Bash syntax checks for all shell scripts/tests, `git diff --check`, and HTTPS `ls-remote` checks. Expected: all exit zero.

- [ ] **Step 2: Open a normal PR**

Push `bas/fix-fleet-install`, open a non-draft PR against `main`, keep the description repository-relative, wait for AI review, validate every finding, and address valid findings without amending commits.

- [ ] **Step 3: Merge reviewed changes**

Merge only after checks and review are clean. Do not force push.

- [ ] **Step 4: Run the fleet install**

From the primary checkout on updated `main`, run `./scripts/sync-dotfiles.sh install` and retain the full exit status and per-host summary.

- [ ] **Step 5: Verify each reachable host**

Confirm the main commit, submodule states, and installer exit status on every reachable host. Report `pi3` separately if Layer-2 reachability is still unavailable; do not count it as a software repair failure.
