# MindRoom LXC NixOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a standalone `mindroom-ai/lxc-nixos` repository that reproduces the current `mindroom` LXC deployment shape without any `openclaw` code or personal secrets.

**Architecture:** Build a self-contained Nix flake under a new local repository, copy the current `mindroom` host composition into repo-local modules, replace dependencies on the larger dotfiles repo with local equivalents, and add a first-class `ragenix` secrets workflow with templates and bootstrap tooling. Generalize the runtime user model so the repo does not depend on Bas-specific accounts or secret material.

**Tech Stack:** Nix flakes, NixOS modules, ragenix/agenix, shell scripting, git

---

### Task 1: Create the standalone repository skeleton

**Files:**
- Create: `/home/basnijholt/Code/lxc-nixos/.gitignore`
- Create: `/home/basnijholt/Code/lxc-nixos/flake.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/README.md`
- Create: `/home/basnijholt/Code/lxc-nixos/modules/base-system.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/modules/lxc-container.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/modules/git-repo-checkouts.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/modules/mindroom-runtime-services.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/modules/agent-env.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/default.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/networking.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/constants.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/secrets-config.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/mindroom.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/cinny.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/element.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/tuwunel.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/caddy.nix`

- [ ] **Step 1: Create the directory tree**

Run: `mkdir -p /home/basnijholt/Code/lxc-nixos/{modules,hosts/mindroom/secrets,secrets/shared,templates,scripts}`
Expected: directory tree exists with no files yet

- [ ] **Step 2: Initialize git**

Run: `git init /home/basnijholt/Code/lxc-nixos`
Expected: `.git/` exists in the new repo

- [ ] **Step 3: Add the base flake and host/module files**

Write the new flake, host composition, and repo-local module files with no imports back into `/home/basnijholt/dotfiles/configs/nixos`.

- [ ] **Step 4: Verify the repo has no `openclaw` references**

Run: `rg -n "openclaw|signal-cli|basnijholt" /home/basnijholt/Code/lxc-nixos`
Expected: no matches except possibly in historical comments that should be removed

### Task 2: Replace parent-repo dependencies with local standalone modules

**Files:**
- Modify: `/home/basnijholt/Code/lxc-nixos/modules/base-system.nix`
- Modify: `/home/basnijholt/Code/lxc-nixos/modules/git-repo-checkouts.nix`
- Modify: `/home/basnijholt/Code/lxc-nixos/modules/mindroom-runtime-services.nix`
- Modify: `/home/basnijholt/Code/lxc-nixos/modules/agent-env.nix`
- Modify: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/*.nix`

- [ ] **Step 1: Replace the personal runtime account**

Introduce a dedicated runtime user, defaulting to `mindroom`, and switch service ownership and runtime paths away from `/home/basnijholt`.

- [ ] **Step 2: Vendor the managed git checkout module**

Copy the behavior from `optional/git-repo-checkouts.nix` into the new repo and wire it into `hosts/mindroom/default.nix`.

- [ ] **Step 3: Keep the current runtime behavior**

Preserve the `mindroom-lab`, `mindroom-chat`, `cinny`, `element`, `tuwunel`, and `caddy` behavior unless a Bas-specific path or ownership assumption requires generalization.

- [ ] **Step 4: Verify there are no imports back to the dotfiles repo**

Run: `rg -n "/home/basnijholt/dotfiles|\\.\\./\\.\\./optional|\\.\\./\\.\\./common" /home/basnijholt/Code/lxc-nixos`
Expected: no matches

### Task 3: Add the standalone secrets workflow

**Files:**
- Create: `/home/basnijholt/Code/lxc-nixos/secrets/shared/secrets.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/secrets/secrets.nix`
- Create: `/home/basnijholt/Code/lxc-nixos/templates/agent-runtime.env.example`
- Create: `/home/basnijholt/Code/lxc-nixos/templates/agent-integrations.env.example`
- Create: `/home/basnijholt/Code/lxc-nixos/templates/agent-tooling.env.example`
- Create: `/home/basnijholt/Code/lxc-nixos/templates/registration-token.example`
- Create: `/home/basnijholt/Code/lxc-nixos/scripts/bootstrap-secrets.sh`
- Create: `/home/basnijholt/Code/lxc-nixos/hosts/mindroom/secrets/.gitkeep`
- Create: `/home/basnijholt/Code/lxc-nixos/secrets/shared/.gitkeep`

- [ ] **Step 1: Add placeholder recipient definitions**

Write `secrets.nix` files that document how consumers replace placeholder recipients with their own user and host keys.

- [ ] **Step 2: Add example plaintext templates**

Create secret templates with variable names and comments only, not real values.

- [ ] **Step 3: Write the bootstrap script**

Implement a shell script that validates required secret files, checks for `ragenix`, and guides the user through creating encrypted secrets from the templates.

- [ ] **Step 4: Verify the repo contains no encrypted personal payloads**

Run: `find /home/basnijholt/Code/lxc-nixos -name '*.age' -o -name 'secrets.nix' | sed -n '1,200p'`
Expected: only placeholder scaffolding and no copied private ciphertext

### Task 4: Document and verify the standalone flake

**Files:**
- Modify: `/home/basnijholt/Code/lxc-nixos/README.md`
- Modify: `/home/basnijholt/Code/lxc-nixos/flake.nix`

- [ ] **Step 1: Write the standalone README**

Document the purpose, excluded scope, Incus bootstrap flow, secrets setup, and build commands.

- [ ] **Step 2: Evaluate the flake**

Run: `nix flake check` in `/home/basnijholt/Code/lxc-nixos`
Expected: evaluation succeeds

- [ ] **Step 3: Build the host**

Run: `nix build .#nixosConfigurations.mindroom.config.system.build.toplevel`
Expected: host builds successfully

- [ ] **Step 4: Sanity-check the host shape**

Run: `rg -n "mindroom-lab|mindroom-chat|git-checkout-mindroom|git-checkout-cinny|git-checkout-element" /home/basnijholt/Code/lxc-nixos`
Expected: the expected services and checkout wiring are present

- [ ] **Step 5: Commit**

```bash
cd /home/basnijholt/Code/lxc-nixos
git add .
git commit -m "feat: scaffold standalone mindroom lxc nixos repo"
```
