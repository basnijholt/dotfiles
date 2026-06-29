# NAS NixOS Migration Plan

This is the living handoff note for the `nas` host. It records the current
state and the remaining operational work. Commands for reinstalling or repeating
the migration belong in `CUTOVER.md`.

## Current State

- Branch: `truenas-nixos-scaffold`
- Draft PR: https://github.com/basnijholt/dotfiles/pull/61
- Base branch: `main`
- Host name in Nix: `nas`
- Last updated: `2026-06-28 post-cutover`

The real NAS has been cut over from TrueNAS to NixOS with this host config. The
destructive storage migration is complete. The data pools are imported by name
and are not described by disko.

## Safety Boundary

- Disko manages only the boot disk and creates the NixOS `zroot`.
- Existing data pools are imported by pool name.
- Do not add data-pool member devices to `disko.nix`.
- Do not run disko on the running NAS unless intentionally reinstalling the boot
  disk again.
- If reinstalling, use `CUTOVER.md` and run the installer-side preflight before
  any destructive command.
- Keep private encrypted dataset names, host IDs, disk serials, LAN-only secret
  material, and SSH keys out of public docs unless they are necessary in
  executable config.
- The `marcella` account name and JB Weston removal are intentional migration
  cleanup decisions.

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
- Ran the disposable VM disko rehearsal:
  `nix build .#checks.x86_64-linux.nas-disko-safety`.
- Ran the phased `nixos-anywhere` cutover on 2026-06-28.
- Ran the installer-side disk preflight before destructive disko.
- Installed NixOS on the boot disk and booted the real NAS.
- Confirmed `tank`, `ssd`, and `zroot` were healthy after first boot.
- Reconciled imported data-pool mountpoints to `/mnt/tank` and `/mnt/ssd`.
- Unlocked encrypted datasets interactively with the NixOS helper.
- Recovered Incus instances from `ssd/.ix-virt` with `incus admin recover`.
- Applied known Incus instance config and fixed required subordinate UID/GID
  passthrough ranges.
- Validated NFS mounts from the PC.
- Removed the obsolete PC TrueNAS API config-backup job from Nix config.
- Added an explicit `nas` DNS record to avoid wildcard `.local` misrouting.
- Added faster Nix cache failure behavior for unavailable LAN caches.

## Remaining Work

### SMB

- [ ] Create or verify Samba passwords for intended users with `smbpasswd`.
- [ ] Validate Time Machine from a macOS client.
- [ ] Validate photo/media access from normal client accounts.
- [ ] Validate guest access from a fresh unauthenticated client.
- [ ] Validate Previous Versions/shadow-copy browsing.
- [ ] Decide whether stock Samba `shadow_copy2` is sufficient long-term.

### Replication And Backups

- [ ] Install inbound replication public keys in
  `/etc/ssh/authorized_keys.d/root`.
- [ ] Refresh SSH host keys and name resolution on pushing hosts.
- [ ] Install outbound replication SSH keys outside this public repo.
- [ ] Authorize the outbound replication public keys on their remote ends.
- [ ] Verify remote SSH access with `BatchMode=yes`.
- [ ] Run each Syncoid service manually once and inspect source/target
  snapshots.
- [ ] Decide whether old TrueNAS-created snapshots should be aged out manually.

### Encryption

- [x] Confirm encrypted roots use passphrase keys.
- [x] Confirm passphrases are recorded/backed up off-box.
- [x] Harden `zfs-unlock-encrypted-datasets` so one skipped key does not abort
  the whole batch.
- [ ] Deploy `zfs-unlock` as the NixOS/OpenZFS successor to the old
  `truenas-unlock` API flow, or accept manual unlocks after reboot.

### Monitoring And Access

- [ ] Decide how Netdata should be reached: SSH tunnel, reverse proxy, or
  Tailscale-only access.
- [ ] Add `/etc/nas-health-alert.env` with `NTFY_URL` if wall/syslog is not
  enough.
- [ ] Validate all disks appear in `smartctl --scan-open` on NixOS.
- [ ] Validate UPS status with `upsc` and the NUT exporter.
- [ ] Confirm the configured UPS name matches the name exposed by the remote NUT
  server.
- [ ] Authenticate host-level Tailscale with `tailscale up`.

## Historical Context

Pre-cutover read-only TrueNAS inspection confirmed the host ID, boot-pool disk,
service surface, data-pool health, SMART status, snapshot tasks, replication
tasks, and Incus state used to shape this config. Those notes are historical
validation context now; do not treat them as commands to run on the current NAS.

## Out Of Scope

- TrueNAS web UI replacement.
- iSCSI recreation for the removed JB Weston setup.
- Actual Budget migration.
- Automatic destructive cutover.
