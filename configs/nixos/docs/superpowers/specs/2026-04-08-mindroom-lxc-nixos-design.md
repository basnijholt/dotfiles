# MindRoom LXC NixOS Standalone Repo Design

## Goal

Create a standalone dotfiles-style repository for `mindroom-ai/lxc-nixos` that preserves the current `hosts/mindroom` Incus LXC deployment shape while removing all `openclaw`-specific logic and replacing personal secrets with a reusable, documented secrets workflow.

## Current Source of Truth

The existing container definition lives in this repository under:

- `flake.nix`
- `configuration.nix`
- `optional/lxc-container.nix`
- `optional/mindroom-runtime-services.nix`
- `optional/agent-env.nix`
- `optional/git-repo-checkouts.nix`
- `optional/virtualization.nix`
- `hosts/mindroom/default.nix`
- `hosts/mindroom/{networking,secrets-config,mindroom,cinny,element,tuwunel,caddy,constants}.nix`

The parts that must not move into the new repository are:

- `hosts/mindroom/openclaw.nix`
- `optional/openclaw/services.nix`
- `optional/openclaw/overlay.nix`
- `signal-cli` package installation
- passwordless sudo rules added only for the `openclaw` agent workflow
- personal user definitions, hashed passwords, SSH keys, and shell/home-manager state from `common/*`
- any encrypted secret material or recipient definitions tied to private infrastructure beyond what is needed as generic examples/templates

## Design Principles

1. Keep the user-facing layout close to the current dotfiles repo.
2. Preserve a turnkey default host that behaves like the current `mindroom` LXC minus `openclaw`.
3. Separate general-purpose LXC and runtime modules from host composition so the repo can evolve cleanly.
4. Make secrets an explicit supported workflow, not an undocumented prerequisite.
5. Ship templates, scaffolding, and validation, but never include personal secret values.

## Target Repository Shape

The standalone repository should remain small and opinionated:

```text
lxc-nixos/
├── flake.nix
├── flake.lock
├── README.md
├── hosts/
│   └── mindroom/
│       ├── default.nix
│       ├── networking.nix
│       ├── constants.nix
│       ├── secrets-config.nix
│       ├── mindroom.nix
│       ├── cinny.nix
│       ├── element.nix
│       ├── tuwunel.nix
│       ├── caddy.nix
│       └── secrets/
│           ├── secrets.nix
│           └── .gitkeep
├── modules/
│   ├── base-system.nix
│   ├── lxc-container.nix
│   ├── git-repo-checkouts.nix
│   ├── mindroom-runtime-services.nix
│   └── agent-env.nix
├── secrets/
│   └── shared/
│       ├── secrets.nix
│       └── .gitkeep
├── templates/
│   ├── agent-runtime.env.example
│   ├── agent-integrations.env.example
│   ├── agent-tooling.env.example
│   └── registration-token.example
└── scripts/
    └── bootstrap-secrets.sh
```

## Nix Structure

### Flake

The new `flake.nix` should:

- expose one main `nixosConfigurations.mindroom`
- include `ragenix.nixosModules.default`
- use a small `commonModules` list built from repo-local modules only
- keep the repository self-contained, with no imports back into the original dotfiles repo
- avoid depending on the original repo's `common/*`, `home-manager`, or `comin` layers

### Host Composition

`hosts/mindroom/default.nix` should remain the top-level composition layer and import:

- `../../modules/base-system.nix`
- `../../modules/lxc-container.nix`
- `../../modules/git-repo-checkouts.nix`
- `../../modules/mindroom-runtime-services.nix`
- `../../modules/agent-env.nix`
- `./networking.nix`
- `./secrets-config.nix`
- `./mindroom.nix`
- `./cinny.nix`
- `./element.nix`
- `./tuwunel.nix`
- `./caddy.nix`

It should not import any `openclaw` modules or install `signal-cli`.

### Module Boundaries

`modules/base-system.nix`
- defines a minimal standalone base for the container
- replaces the personal/common dotfiles baseline from the current repo
- creates or configures the runtime user used by MindRoom services
- enables only the generic system services needed for a usable remote-managed container
- avoids private SSH keys, hashed passwords, and personal shell setup

`modules/lxc-container.nix`
- generic Incus LXC container behavior
- rootfs definition
- `systemd-resolved` fix
- `networking.useHostResolvConf = false`

`modules/git-repo-checkouts.nix`
- local copy of the managed checkout module used by `mindroom`, `cinny`, and `element`
- removes the dependency on the larger dotfiles repo
- keeps the existing `git-checkout-<name>.service` behavior so the runtime module continues to work unchanged

`modules/mindroom-runtime-services.nix`
- systemd units for `mindroom-lab`
- systemd units for `mindroom-chat`
- systemd units for `mindroom-cinny`
- systemd units for `mindroom-element-build`
- systemd units for `mindroom-element`

`modules/agent-env.nix`
- shared `age.identityPaths`
- shared secret location convention
- host-specific `agent-runtime-env`
- shared `agent-integrations-env`
- shared `agent-tooling-env`

The host-local modules should keep the app-specific repo checkout and reverse-proxy behavior because those are part of the default deployment shape the user wants to preserve.

## Runtime User Model

The current host assumes a personal `basnijholt` account from the parent dotfiles repo. The standalone repo should replace that with a repo-local runtime user model.

- introduce a dedicated runtime user, defaulting to `mindroom`
- make the username and group overridable through module options
- use that user consistently for:
  - service ownership
  - decrypted secret ownership
  - runtime working directories
  - managed git checkouts where appropriate

The extracted repository should not depend on any personal login account to function.

## Secrets Architecture

The new repository should standardize on `ragenix`.

### Required Secret Inventory

Shared secrets:

- `secrets/shared/agent-integrations.env.age`
- `secrets/shared/agent-tooling.env.age`

Host-specific secrets:

- `hosts/mindroom/secrets/agent-runtime.env.age`
- `hosts/mindroom/secrets/registration-token.age`

### Recipient Definitions

Each secrets scope gets its own `secrets.nix`:

- `secrets/shared/secrets.nix`
- `hosts/mindroom/secrets/secrets.nix`

The files should contain placeholder/example recipients and clear comments explaining that users must replace them with their own user and host keys.

### Bootstrap Workflow

`scripts/bootstrap-secrets.sh` should provide a supported setup path:

1. accept a host name, defaulting to `mindroom`
2. verify `ragenix` is available
3. print instructions for obtaining the host age-compatible recipient from `/etc/ssh/ssh_host_ed25519_key.pub`
4. check whether the host recipient is listed in the relevant `secrets.nix` files
5. copy example plaintext templates into a temporary working area if the encrypted files do not exist yet
6. invoke `ragenix` for each required secret file
7. exit with actionable errors when a required encrypted file is missing

The bootstrap script should not fabricate secrets automatically. It should reduce friction and validate structure, while leaving values under user control.

### Runtime Consumption

Modules should consume only decrypted secret paths:

- `config.age.secrets.agent-runtime-env.path`
- `config.age.secrets.agent-integrations-env.path`
- `config.age.secrets.agent-tooling-env.path`
- `config.age.secrets.registration-token.path`

This keeps the service layer generic and free from per-user secret content.

The secret file owners should follow the dedicated runtime user rather than a personal login account.

## Documentation

`README.md` should be written as a practical standalone guide:

1. what the repository provides
2. what it intentionally excludes
3. how to create an Incus LXC container
4. how to add the host recipient to the repo
5. how to create the encrypted secrets from templates
6. how to build and switch the `mindroom` configuration
7. what services should come up after activation

The README should explicitly say that this repository does not ship production secrets and that consumers must create their own encrypted secret files.

## Migration Scope

Content to migrate with minimal changes:

- LXC base module
- managed git checkout module
- runtime service module
- mindroom host modules except `openclaw`
- existing constant values and routing logic

Content to rewrite or sanitize:

- imports that currently point back into the large dotfiles repo
- the current dependency on personal `common/*` modules
- the current dependency on `basnijholt` as the service user
- secret path conventions that assume the old repository layout
- recipient definition files that currently reference personal keys
- documentation, which should become standalone and self-sufficient

Content to omit:

- any `openclaw` service or overlay logic
- any personal SSH recipients
- any encrypted secret payloads from the current repo

## Verification Strategy

The extracted repository should be considered complete when:

1. `nix flake check` succeeds in the new repo
2. `nix build .#nixosConfigurations.mindroom.config.system.build.toplevel` succeeds
3. the host configuration evaluates without references to the original dotfiles repo
4. there are no imports or package references to `openclaw`
5. the README and bootstrap script are sufficient for a new user to understand how to supply secrets

## Risks

- The current configuration relies on custom modules from the larger dotfiles repo, especially the git checkout behavior. If those modules are required, the new repo must either vendor them or replace them with simpler local equivalents.
- Replacing the personal runtime user with a standalone service user changes file paths and ownership semantics. The extraction should do this deliberately and consistently rather than keeping `basnijholt` hardcoded.
- Secret bootstrapping can feel solved in theory but still fail in practice if error messages are vague. The script and README must assume no prior knowledge.
- Keeping the host shape close to the current repo is useful now, but it should not prevent later extraction of reusable profiles if the repository grows.

## Recommended Implementation Order

1. Inventory all transitive imports and dependencies needed by the current `mindroom` host.
2. Create the new standalone repository skeleton.
3. Copy and sanitize the LXC, runtime, and host modules.
4. Vendor or replace any supporting modules that are required for evaluation.
5. Add secrets templates, recipient placeholders, and the bootstrap script.
6. Write the standalone README.
7. Run evaluation and build verification on the new flake.
