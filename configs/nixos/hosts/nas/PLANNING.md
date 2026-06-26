# NAS NixOS Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current TrueNAS deployment with this NixOS `nas` host
while preserving existing data pools and service behavior as closely as
possible.

**Architecture:** NixOS owns only the boot disk layout. Existing data pools are
imported by name and are not described by disko. NAS services are split into
small host modules for storage, health, SMB, NFS, replication, identity,
networking, and virtualization.

**Tech Stack:** NixOS flakes, disko, ZFS, Sanoid/Syncoid, Samba, NFS, SMART,
NUT, Netdata, Prometheus exporters, Docker, and Incus.

---

## Current State

- Branch: `truenas-nixos-scaffold`
- Draft PR: https://github.com/basnijholt/dotfiles/pull/61
- Base branch: `main`
- Host name in Nix: `nas`
- Last updated from local workspace: `2026-06-26 23:37 PDT`

The scaffold currently builds locally. It is still a migration scaffold, not a
configuration that has been booted on the real NAS.

## Safety Rules

- Do not change the live TrueNAS deployment while validating this PR.
- SSH to TrueNAS is allowed only for read-only inspection commands.
- Do not run `disko` while booted into TrueNAS.
- Do not add any data-pool member device to `disko.nix`.
- Do not run the destructive disko command until the remote-only disko preflight
  in `CUTOVER.md` has passed in the installer environment.
- Do not enumerate private encrypted dataset names in public docs or PR text.
  The unlock helper discovers unavailable encrypted roots dynamically.
- Do not repeat host IDs, disk serials, LAN addresses, MAC addresses, or user
  account names in public planning docs unless they are necessary for executable
  config.
- Keep `services.comin.enable = false` until a manual cutover has succeeded.
- Keep unrelated local files out of this PR, especially archive migration notes.
- The `marcella` identity name is intentional. Do not restore the old longer
  account name or the retired JB Weston identity unless explicitly requested.

## Files

- Create/maintain: `configs/nixos/hosts/nas/PLANNING.md`
- Main entry point: `configs/nixos/hosts/nas/default.nix`
- Boot disk layout: `configs/nixos/hosts/nas/disko.nix`
- Root filesystem placeholder: `configs/nixos/hosts/nas/hardware-configuration.nix`
- Data-pool import, scrubs, snapshots, unlock helper:
  `configs/nixos/hosts/nas/storage.nix`
- Health and monitoring: `configs/nixos/hosts/nas/health.nix`
- SMB compatibility: `configs/nixos/hosts/nas/samba.nix`
- NFS exports: `configs/nixos/hosts/nas/nfs.nix`
- Sanoid/Syncoid replication: `configs/nixos/hosts/nas/replication.nix`
- Docker/Incus: `configs/nixos/hosts/nas/virtualization.nix`
- Cutover runbook: `configs/nixos/hosts/nas/CUTOVER.md`

## Validated Locally

- [x] `nix build '.#nixosConfigurations.nas.config.system.build.toplevel' --no-link --print-out-paths`
- [x] Disko target evaluates to the current TrueNAS boot-pool disk by stable
  by-id path. The exact value remains in executable config and is not repeated
  in this public planning doc.
- [x] `/` and `/boot` are supplied by disko-managed `zroot` and `EFI-NAS`.
- [x] Data pools evaluate as ZFS `extraPools`; they are not in disko.
- [x] ZFS force-import and boot-time encryption credential prompts are disabled.
- [x] Generated Samba config loads with `testparm -s`.
- [x] Generated Syncoid service scripts pass `bash -n`.
- [x] Generated Incus helper script passes `bash -n`.
- [x] Replication timers evaluate as wanted by `timers.target`.
- [x] Remote replication services evaluate with `ConditionPathExists` guards.
- [x] Incus services evaluate with `zfs.target` ordering.
- [x] NAS OpenSSH config allows key-only root login from the LAN for inbound
  Syncoid pushes while keeping keys outside the public repo.
- [x] SMARTD and ZED invoke a shared `nas-health-alert` hook that logs, walls,
  and can send ntfy when `/etc/nas-health-alert.env` exists.

## Live TrueNAS Facts Observed Read-Only

- Host ID observed on TrueNAS matches the configured NixOS host ID. The value is
  intentionally not repeated in this public planning doc.
- Current boot pool is on the NVMe device targeted by `disko.nix` for final
  cutover.
- Data pools are healthy and intentionally imported by name on NixOS.
- TrueNAS services observed in use include SMB, NFS, SSH, UPS, iSCSI, and Incus.
- SMART health was passing for all observed disks at inspection time.
- TrueNAS has local snapshot tasks and replication tasks; this PR maps them to
  Sanoid/Syncoid concepts but needs first-run verification.
- Incus has live instances and daemon state; this PR recreates daemon config and
  known instance settings only after instances are imported.

## Remaining Work From The Four Big Gaps

### Task 1: Boot/root cutover risk

**Status:** Mostly configured, still inherently destructive at cutover.

- [x] Point `disko.nix` at the current TrueNAS boot-pool disk.
- [x] Keep data pools outside disko.
- [x] Document that running disko destroys the TrueNAS boot pool.
- [x] Document remote-only disko preflight using stable by-id evaluation,
  `lsblk`, `zpool import`, ZFS label inspection, and `wipefs --no-act`.
- [ ] Before cutover, confirm device identity from the NixOS installer by
  comparing the `disko.nix` target with `/dev/disk/by-id/`.
- [ ] Before cutover, run the remote-only disko preflight and confirm no
  `tank`/`ssd` ZFS labels are present on the disko target or its partitions.
- [ ] Run the cutover sequence in `CUTOVER.md` only after a clean TrueNAS
  shutdown and a final backup decision.

### Task 2: SMB compatibility

**Status:** Close enough to test, not byte-for-byte TrueNAS-equivalent.

- [x] Rename server identity to `NAS`.
- [x] Keep the intended `marcella` account name and JB Weston removal.
- [x] Recreate observed SMB share names and primary access modes.
- [x] Recreate guest access semantics for the guest-enabled share.
- [x] Add stock Samba fruit, streams, io_uring, and shadow-copy support.
- [ ] Validate macOS Time Machine from a client.
- [ ] Validate photo/media access from the normal client accounts.
- [ ] Validate guest access from a fresh unauthenticated client.
- [ ] Validate Windows or macOS snapshot browsing against existing TrueNAS-style
  snapshot names.
- [ ] Decide whether stock `shadow_copy2` behavior is sufficient. TrueNAS uses
  private Samba VFS modules that stock NixOS Samba does not ship.
- [ ] Create Samba passwords on first boot with `smbpasswd -a` for intended
  users.

### Task 3: Snapshots and replication

**Status:** Local snapshots and replication services are declared; first-run
behavior still needs validation.

- [x] Replace the NAS scaffold's snapshot policy with Sanoid.
- [x] Keep existing non-Sanoid snapshots preserved.
- [x] Add local Syncoid replication service.
- [x] Add remote Syncoid services guarded by local SSH key file existence.
- [x] Allow inbound root Syncoid pushes by key from the LAN without committing
  source host keys to the public repo.
- [ ] Install inbound replication public keys in
  `/etc/ssh/authorized_keys.d/root` during cutover.
- [ ] Refresh SSH host keys and verify `truenas.local` or replacement DNS from
  each pushing host.
- [ ] Install replication SSH keys outside public Nix config.
- [ ] Verify remote SSH access with `BatchMode=yes` before starting timers.
- [ ] Run each replication service manually once and inspect source and target
  snapshots.
- [ ] Decide whether old TrueNAS-created snapshots should age out manually or be
  kept indefinitely. Sanoid will not prune snapshot names it did not create.

### Task 4: Docker and Incus state

**Status:** Daemon shape is declared; workload data movement remains.

- [x] Enable Docker with observed DNS settings.
- [x] Enable Incus.
- [x] Preseed Incus bridge, ZFS storage pool, and default profile.
- [x] Add `nas-apply-incus-config` for known imported instances.
- [x] Keep Actual Budget out of scope.
- [ ] Export or otherwise preserve live Incus instance root filesystems before
  destroying the boot pool.
- [ ] Import Incus instances after first NixOS boot.
- [ ] Run `nas-apply-incus-config` after import.
- [ ] Start instances one at a time and validate service behavior.

## Monitoring And Visualization

Configured in `health.nix`:

- SMART monitoring through `smartd`, with autodetected disk checks.
- ZFS event daemon settings for verbose delayed event notifications.
- Shared `nas-health-alert` hook for SMARTD/ZED. It logs to syslog, sends wall
  notifications, and optionally sends ntfy when a runtime env file is present.
- Netdata bound to `127.0.0.1` for local web visualization.
- Prometheus exporters for node/systemd, SMART, ZFS pools, and NUT/UPS.
- UPS monitoring through the existing remote NUT server.

Open monitoring work:

- [ ] Decide how the Netdata UI will be reached after cutover, for example SSH
  tunnel, reverse proxy, or Tailscale-only access.
- [ ] Decide whether to add Grafana/Prometheus server config here or consume the
  exporters from an existing metrics host.
- [ ] Add `/etc/nas-health-alert.env` with an `NTFY_URL` if wall/syslog
  notifications are not enough.
- [ ] Validate that all expected disks appear in `smartctl --scan-open` on
  NixOS.
- [ ] Validate UPS status with `upsc` and the NUT exporter after first boot.
- [ ] Disable or remove the PC TrueNAS config-backup job at cutover; it depends
  on the TrueNAS API.

## Safe Local Validation Commands

Run from `configs/nixos` unless noted:

```bash
nix build '.#nixosConfigurations.nas.config.system.build.toplevel' --no-link --print-out-paths
nix eval --json '.#diskoConfigurations.nas.disko.devices.disk.main.device'
nix eval --json '.#nixosConfigurations.nas.config.boot.zfs.extraPools'
nix eval --json '.#nixosConfigurations.nas.config.boot.zfs.forceImportRoot'
nix eval --json '.#nixosConfigurations.nas.config.boot.zfs.requestEncryptionCredentials'
nix eval --json '.#nixosConfigurations.nas.config.services.sanoid.templates.nas-default'
```

For generated scripts, build first, then inspect/evaluate the store paths before
executing anything. Do not run service scripts against the live TrueNAS machine.

## Read-Only TrueNAS Validation Ideas

These are allowed only as inspection commands. Do not change service state.

```bash
zpool status
zpool list
zfs list -o name,mountpoint,encryptionroot,keystatus -t filesystem,volume
midclt call service.query
midclt call pool.snapshottask.query
midclt call replication.query
testparm -s
incus list
incus storage list
incus network list
incus profile list
smartctl --scan-open
```

If any command would write state, start/stop a service, import/export a pool,
load keys, mount datasets, or alter Incus/SMB/NFS config, do not run it on
TrueNAS.

## Cutover Checklist

- [ ] Read `CUTOVER.md` fully in the same context window doing the work.
- [ ] Confirm the PR branch is up to date with the intended commit.
- [ ] Confirm backups are acceptable.
- [ ] Perform final read-only TrueNAS health checks.
- [ ] Shut down TrueNAS cleanly.
- [ ] Boot NixOS installer.
- [ ] Run the remote-only disko preflight from `CUTOVER.md`.
- [ ] Confirm the disko target is the boot-pool disk and no `tank`/`ssd` labels
  are present on the target or its partitions.
- [ ] Run disko and `nixos-install` for `.#nas`.
- [ ] Boot NixOS.
- [ ] Confirm ZFS import, health services, SMB/NFS export state, monitoring, and
  timers.
- [ ] Unlock encrypted datasets interactively.
- [ ] Create Samba passwords.
- [ ] Install inbound replication public keys for root and verify pusher hosts.
- [ ] Install replication SSH keys and test remote replication manually.
- [ ] Import Incus instances and run `nas-apply-incus-config`.
- [ ] Authenticate Tailscale.
- [ ] Validate clients before treating the migration as complete.

## Out Of Scope

- TrueNAS web UI replacement.
- iSCSI recreation for the removed JB Weston setup.
- Actual Budget migration.
- Automatic destructive cutover.
