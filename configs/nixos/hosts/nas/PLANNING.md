# NAS NixOS Migration Plan

This is the living handoff note for the `nas` host.
It records the current state and the remaining operational work.
Commands for reinstalling or repeating the migration belong in `CUTOVER.md`.

## Current State

- Base migration PR: https://github.com/basnijholt/dotfiles/pull/61
- Follow-up PR: https://github.com/basnijholt/dotfiles/pull/62
- Backup monitoring / comin follow-up PR: https://github.com/basnijholt/dotfiles/pull/63
- Post-PR follow-ups: B2 success marker, `ncps` Cachix proxy fix, B2 running-state watchdog guard, and a narrow SSD replication skip for the rebuildable `nix-cache` Incus dataset.
- Monitoring dashboard: Grafana scrapes the NAS Prometheus exporters; host Netdata stays localhost-only.
- Base branch: `main`
- Host name in Nix: `nas`
- Last updated: `2026-06-29 post-cutover validation`

The real NAS has been cut over from TrueNAS to NixOS with this host config.
The destructive storage migration is complete.
The data pools are imported by name and are not described by disko.

## Safety Boundary

- Disko manages only the boot disk and creates the NixOS `zroot`.
- Existing data pools are imported by pool name.
- Do not add data-pool member devices to `disko.nix`.
- Do not run disko on the running NAS unless intentionally reinstalling the boot disk again.
- If reinstalling, use `CUTOVER.md` and run the installer-side preflight before any destructive command.
- Keep private encrypted dataset names, host IDs, disk serials, LAN-only secret material, and SSH keys out of public docs unless they are necessary in executable config.
- The `marcella` account name and JB Weston removal are intentional migration cleanup decisions.

## Relevant Files

- Entry point: `default.nix`
- Boot layout: `disko.nix`
- Filesystems: `hardware-configuration.nix`
- ZFS import/scrubs/snapshots/unlock helper: `storage.nix`
- Health and monitoring: `health.nix`
- SMB: `samba.nix`
- NFS: `nfs.nix`
- Sanoid/Syncoid: `replication.nix`
- Docker/Incus: `virtualization.nix`
- Canonical runbook: `CUTOVER.md`
- Host overview: `README.md`

## Completed

- Built the `nas` NixOS toplevel locally.
- Verified the evaluated disko target is the old TrueNAS boot-pool disk.
- Verified data pools evaluate as ZFS `extraPools`; they are outside disko.
- Ran the disposable VM disko rehearsal: `nix build .#checks.x86_64-linux.nas-disko-safety`.
- Ran the phased `nixos-anywhere` cutover on 2026-06-28.
- Ran the installer-side disk preflight before destructive disko.
- Installed NixOS on the boot disk and booted the real NAS.
- Confirmed `tank`, `ssd`, and `zroot` were healthy after first boot.
- Reconciled imported data-pool mountpoints to `/mnt/tank` and `/mnt/ssd`.
- Unlocked encrypted datasets interactively with the NixOS helper.
- Recovered Incus instances from `ssd/.ix-virt` with `incus admin recover`.
- Applied known Incus instance config and fixed required subordinate UID/GID passthrough ranges.
- Applied per-instance Incus memory caps (`nixos` 40 GiB, `docker` 6 GiB; `nix-cache` 24 GiB from recovery).
- Fixed `nas-apply-incus-config` to use the Incus 7 LTS `key=value` syntax (commit `c96eaf1`); the deprecated `key value` form errored on `raw.lxc` and aborted the reconciler under `set -e` before the memory caps were applied.
- Validated NFS mounts from the PC.
- Confirmed NFS exports from the NAS.
- Validated unauthenticated SMB access to the guest-enabled share from a fresh `smbclient` invocation.
- Validated SMB password authentication and read/write access for `basnijholt` and `marcella`.
- Added a Nix-managed `nas-smb-permissions` service that sets the Time Machine share root owner/group and verifies the existing mode.
- Validated Time Machine access from macOS after deploying the share root group/mode fix.
- Validated authenticated SMB media access from macOS Finder.
- Removed the obsolete PC TrueNAS API config-backup job from Nix config.
- Added an explicit `nas` DNS record to avoid wildcard `.local` misrouting.
- Added faster Nix cache failure behavior for unavailable LAN caches.
- Locked down the local `~/nas-cutover` staging directory to mode `0700` without reading its contents.
- Updated the declarative `truenas.local` SSH known-host key to the post-migration NixOS host key.
- Switched the real NAS to the config containing that updated compatibility host key.
- Confirmed the NAS system state is running with no failed host units.
- Confirmed all ZFS pools are healthy after the post-cutover rebuild.
- Confirmed Incus containers `docker`, `nix-cache`, and `nixos` are running.
- Confirmed Netdata, Prometheus node/ZFS/SMART/NUT exporters, smartd, upsmon, and ZED are running.
- Configured a Grafana `NAS health` dashboard backed by the NAS node, ZFS, SMART, and NUT Prometheus exporters.
- Confirmed host-level Tailscale is authenticated.
- Confirmed the `zfs-unlock` NAS receiver side is installed as a restricted SSH forced-command account.
- Confirmed direct `zfs-unlock` SSH access from the PC is denied.
- Confirmed the `zfs-unlock` client side on `pi4` is installed, enabled, and running as a system service.
- Ran `zfs-unlock doctor` from `pi4`; config parsing, SSH key lookup, NAS reachability, and receiver status checks passed.
- Ran `zfs-unlock status` from `pi4`; the managed datasets reported unlocked.
- Installed the staged inbound root replication keys from `~/nas-cutover` into `/etc/ssh/authorized_keys.d/root` on the NAS without reading their contents.
- Installed the staged outbound NAS replication keys from `~/nas-cutover` into `/etc/ssh/nas-replication-*.ed25519` without reading their contents.
- Verified the outbound NAS replication keys authenticate to the NUC and Hetzner targets with `BatchMode=yes`.
- Verified the inbound root replication keys match the root public-key fingerprints on `hp`, `nuc`, and `pi4`.
- Confirmed the PC NFS mounts are present and resolve to the NAS address.
- Merged and deployed follow-up PR #62 so inbound push jobs use the NAS LAN IP instead of `truenas.local`.
- Merged and deployed follow-up PR #63 so backup monitoring and `comin` are active on the NAS.
- Confirmed `ntfy` notifications work with the `nas-alerts` topic from both a direct `curl` test and a real service alert.
- Confirmed a real reboot returned the pools, encrypted datasets, SMB/NFS services, and Incus containers.
- Confirmed `systemd-tmpfiles --clean` succeeds after the systemd 260.2 update.
- Fixed the `ncps` binary-cache proxy so it no longer proxies Cachix-style UUID NAR URLs that trigger `invalid nar hash`.
- Deployed that `ncps` fix to the `nix-cache` Incus container and smoke-tested both the former 500 path and a normal narinfo hit.
- Confirmed the Backblaze B2 rclone job completed successfully after the persistent success-marker change.
- Confirmed the NAS B2 watchdog reports the successful B2 run as fresh.
- Kept Incus `.ix-virt` in SSD replication for restore fidelity, but committed a narrow Syncoid skip for the rebuildable `ssd/.ix-virt/containers/nix-cache` dataset.

## Remaining Work

### SMB

- [x] Create or verify Samba passwords for intended users with `smbpasswd`.
- [x] Manage Time Machine share root owner/group and verify the existing mode for `basnijholt` and `marcella`.
- [x] Validate Time Machine from a macOS client.
- [x] Validate photo access from normal client accounts.
- [x] Validate media access from normal client accounts.
- [x] Validate guest access from a fresh unauthenticated client.
- [x] Previous Versions / `shadow_copy2`: not needed — no Windows clients here
  (macOS uses Time Machine). Removed the dead `shadow_copy2` config; restore from
  `.zfs/snapshot/` directly if an old file is ever needed.

### Replication And Backups

- [x] Install inbound replication public keys in `/etc/ssh/authorized_keys.d/root`.
- [x] Refresh SSH host keys on pushing hosts.
- [x] Install outbound replication SSH keys outside this public repo.
- [x] Authorize the outbound replication public keys on their remote ends.
- [x] Verify outbound remote SSH access with `BatchMode=yes`.
- [x] Merge and deploy follow-up PR #62 so inbound push jobs use the NAS LAN IP instead of `truenas.local`; `pi4` does not resolve `truenas.local` reliably.
- [x] Add `OnFailure=` alert hooks to the declared NAS replication units.
- [x] Exclude `tank/backups` from NAS-local Sanoid snapshots so replicated backup targets are not refreshed by local autosnapshots.
- [x] Add an hourly snapshot-freshness watchdog for the local SSD mirror, inbound host pushes, and Hetzner website pull target.
- [ ] Let the currently running `ssd -> nuc` catch-up finish, or intentionally restart it after deploying the new exclude if skipping the current `nix-cache` transfer matters.
- [ ] Inspect source/target snapshots after the `ssd -> nuc` catch-up finishes.
- [x] Reconcile the failed Hetzner website replication target; the stale NAS target was renamed aside and a fresh pull completed.
- [x] Reconcile the Backblaze B2 rclone job in config so it skips when rclone config is absent and syncs from the stable local SSD mirror instead of live Docker paths.
- [x] Deploy the Backblaze B2 rclone change to the Incus container that owns the job, then inspect the next run.
- [x] Add failure alerting or a freshness check for the authoritative Backblaze B2 job once its owner container and backup method are decided.
- [x] Confirm the authoritative Backblaze B2 job completed once and wrote a persistent success marker.
- [x] Confirm the NAS B2 watchdog reports the B2 success marker as fresh.
- [x] Keep `.ix-virt` backed up for Incus restore fidelity, but skip only the rebuildable `ssd/.ix-virt/containers/nix-cache` dataset in future SSD Syncoid jobs.
- [ ] Decide whether old TrueNAS-created snapshots and pre-exclusion NAS-local `tank/backups` autosnapshots should be aged out manually.

### Encryption

- [x] Confirm encrypted roots use passphrase keys.
- [x] Confirm passphrases are recorded/backed up off-box.
- [x] Harden `zfs-unlock-encrypted-datasets` so one skipped key does not abort the whole batch.
- [x] Deploy the NAS-side `zfs-unlock` restricted SSH receiver.
- [x] Finish the `pi4` client side of `zfs-unlock`: install the client, install the configured private key, enable the system service, and use a NAS target that resolves reliably from `pi4`.
- [x] Run a non-destructive `zfs-unlock status` check from `pi4` to the NAS receiver.
- [x] Run one real unlock pass from `pi4` after the managed datasets are intentionally unavailable, and confirm expected encrypted roots become available.

### Monitoring And Access

- [x] Keep host Netdata localhost-only and use Grafana plus Prometheus exporters as the normal NAS dashboard.
- [x] Configure ntfy alerts declaratively on the `nas-alerts` topic.
- [x] Validate all disks appear in `smartctl --scan-open` on NixOS.
- [x] Validate UPS status with `upsc` and the NUT exporter.
- [x] Confirm the configured UPS name matches the name exposed by the remote NUT server.
- [x] Authenticate host-level Tailscale with `tailscale up`.

### Deploy

- [x] Merge and manually deploy the backup monitoring follow-up PR to `nas`; that deployment enables `comin` for future NAS updates.
- [ ] Confirm `comin` deploys the latest post-PR follow-up commits on the NAS after the current long-running replication work is out of the way.

### Reboot Validation

- [x] Reboot the NAS once after the migration.
- [x] Confirm pools import, encrypted datasets unlock, NFS/SMB return, and Incus containers auto-start after that reboot.

## Historical Context

Pre-cutover read-only TrueNAS inspection confirmed the host ID, boot-pool disk, service surface, data-pool health, SMART status, snapshot tasks, replication tasks, and Incus state used to shape this config.
Those notes are historical validation context now; do not treat them as commands to run on the current NAS.

## Out Of Scope

- TrueNAS web UI replacement.
- iSCSI recreation for the removed JB Weston setup.
- Actual Budget migration.
- Automatic destructive cutover.
