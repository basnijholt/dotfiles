# NAS NixOS Migration Plan

This is the living handoff note for the `nas` host.
It records the current state and the remaining operational work.
Commands for reinstalling or repeating the migration belong in `CUTOVER.md`.

## Current State

- Branch: `truenas-nixos-scaffold`
- Draft PR: https://github.com/basnijholt/dotfiles/pull/61
- Base branch: `main`
- Host name in Nix: `nas`
- Last updated: `2026-06-28 post-cutover`

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
- Confirmed host-level Tailscale is authenticated.
- Confirmed the `zfs-unlock` NAS receiver side is installed as a restricted SSH forced-command account.
- Confirmed direct `zfs-unlock` SSH access from the PC is denied.
- Confirmed the `zfs-unlock` client side on `pi4` is not complete yet: the configured private key is missing, no client executable is installed, and no user service is enabled.

## Remaining Work

### SMB

- [ ] Create or verify Samba passwords for intended users with `smbpasswd`.
- [ ] Validate Time Machine from a macOS client.
- [ ] Validate photo/media access from normal client accounts.
- [x] Validate guest access from a fresh unauthenticated client.
- [x] Previous Versions / `shadow_copy2`: not needed — no Windows clients here
  (macOS uses Time Machine). Removed the dead `shadow_copy2` config; restore from
  `.zfs/snapshot/` directly if an old file is ever needed.

### Replication And Backups

- [ ] Install inbound replication public keys in `/etc/ssh/authorized_keys.d/root`.
- [ ] Refresh SSH host keys and name resolution on pushing hosts.
- [ ] Install outbound replication SSH keys outside this public repo.
- [ ] Authorize the outbound replication public keys on their remote ends.
- [ ] Verify remote SSH access with `BatchMode=yes`.
- [ ] Run each Syncoid service manually once and inspect source/target snapshots.
- [ ] Decide whether old TrueNAS-created snapshots should be aged out manually.

### Encryption

- [x] Confirm encrypted roots use passphrase keys.
- [x] Confirm passphrases are recorded/backed up off-box.
- [x] Harden `zfs-unlock-encrypted-datasets` so one skipped key does not abort the whole batch.
- [x] Deploy the NAS-side `zfs-unlock` restricted SSH receiver.
- [ ] Finish the `pi4` client side of `zfs-unlock`: install the client, install the configured private key, enable the user service, and use a host target that resolves reliably from `pi4`.
- [ ] Run a non-destructive `zfs-unlock status` check from `pi4` to the NAS receiver.
- [ ] After the status check works, run one real unlock pass from `pi4` and confirm expected encrypted roots become available.

### Monitoring And Access

- [ ] Decide how Netdata should be reached: SSH tunnel, reverse proxy, or Tailscale-only access.
- [ ] Add `/etc/nas-health-alert.env` with `NTFY_URL` if wall/syslog is not enough.
- [x] Validate all disks appear in `smartctl --scan-open` on NixOS.
- [x] Validate UPS status with `upsc` and the NUT exporter.
- [x] Confirm the configured UPS name matches the name exposed by the remote NUT server.
- [x] Authenticate host-level Tailscale with `tailscale up`.

### Incus Container Cleanup

Investigated the failed units via read-only journals (2026-06-28). None were
repo config bugs:

- `github-backup-sync.service` (`docker` + `nixos` instances): fails on GitHub
  auth — no `gh` token on `docker`, expired token ("Bad credentials") on
  `nixos`. `gh`'s interactive auth did not survive the move. Declarative fix
  landed: `github-backup-sync.nix` now loads an optional
  `/etc/github-backup-sync.env` (`GH_TOKEN=...`), kept off-repo.
  - [ ] Drop a valid `GH_TOKEN` into `/etc/github-backup-sync.env` on the
    affected instances (or manage it via ragenix).
- `comin.service` (`docker`): transient boot-time DNS failure ("Could not
  resolve host: github.com") during the cutover window; hit the restart limit
  and stayed failed. Not a config bug.
  - [ ] Confirm it recovers on the next reboot (covered by Reboot Validation);
    if it recurs, investigate the container's DNS/`network-online` ordering.
- `systemd-tmpfiles-clean.service` (`nix-cache` + `nixos`): `statx ... Protocol
  driver not attached` on `/tmp` under idmapped-container mounts — a benign,
  cosmetic LXC/idmap quirk, not a repo bug.
  - [ ] Accept, or mask the unit in the affected instances if the log noise is
    unwanted.
- [ ] Review PostgreSQL collation warnings inside Docker workloads after the host/container move.
- [ ] Decide whether the repeated DHCP option warning inside `docker` is harmless or should be fixed.

### Deploy

- [ ] Run `nixos-rebuild switch --flake .#nas` to deploy `c96eaf1`. Until then the
  Incus memory caps exist only in the live Incus DB, not from declarative config.

### Reboot Validation

- [ ] After `zfs-unlock` and replication are sorted, reboot the NAS once.
- [ ] Confirm pools import, encrypted datasets unlock, NFS/SMB return, and Incus containers auto-start after that reboot.

## Historical Context

Pre-cutover read-only TrueNAS inspection confirmed the host ID, boot-pool disk, service surface, data-pool health, SMART status, snapshot tasks, replication tasks, and Incus state used to shape this config.
Those notes are historical validation context now; do not treat them as commands to run on the current NAS.

## Out Of Scope

- TrueNAS web UI replacement.
- iSCSI recreation for the removed JB Weston setup.
- Actual Budget migration.
- Automatic destructive cutover.
