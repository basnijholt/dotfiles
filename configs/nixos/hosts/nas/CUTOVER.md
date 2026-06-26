# NAS cutover runbook

This runbook is for the final migration from TrueNAS to NixOS on the NAS host.
It assumes the current TrueNAS boot-pool disk will become the NixOS boot disk.

## Safety boundaries

- Do not run disko while booted into TrueNAS.
- Do not run disko against any member of the `tank` or `ssd` pools.
- You do not have physical access to this host, so do not rely on being able to
  recover by unplugging data disks. Use out-of-band console access and complete
  the remote-only disko preflight below.
- Shut TrueNAS down cleanly before booting NixOS with the data disks attached.
- Run only one OS against the data pools at a time.
- Keep `services.comin.enable = false` until the first manual cutover succeeds.

## Boot disk

The NixOS boot layout is declared in `disko.nix`. The exact by-id device path is
intentionally not repeated in this public runbook.

Running disko for `nas` will destroy the existing TrueNAS boot pool on that
disk. The data pools are not described by disko and are imported by pool name.
Before running disko, compare the target in `disko.nix` with the installer
environment and confirm it is the boot-pool disk, not a data-pool member.

## Remote-only disko preflight

Run this from the NixOS installer before the destructive disko command. Stop on
any failed assertion or any output you do not understand.

```bash
set -euo pipefail

cd configs/nixos

for cmd in nix readlink lsblk zpool zdb wipefs grep tee xargs; do
  command -v "$cmd" >/dev/null
done

target="$(nix eval --raw .#diskoConfigurations.nas.disko.devices.disk.main.device)"
target_real="$(readlink -f "$target")"

echo "DISKO TARGET: $target"
echo "RESOLVES TO:   $target_real"
test -b "$target_real"

echo
echo "Visible block devices:"
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS

echo
echo "Importable ZFS pools:"
zpool import

echo
echo "ZFS labels on the disko target and its partitions:"
target_label_dump="/tmp/nas-disko-target-zdb.txt"
: > "$target_label_dump"
while IFS= read -r dev; do
  echo "### $dev" | tee -a "$target_label_dump"
  zdb -l "$dev" 2>/dev/null | tee -a "$target_label_dump" || true
done < <(lsblk -nrpo NAME "$target_real")

if grep -Eq "name: '(tank|ssd)'" "$target_label_dump"; then
  echo "STOP: disko target has tank/ssd ZFS labels"
  exit 1
fi

echo
echo "Non-destructive signature check for disko target only:"
lsblk -nrpo NAME "$target_real" | xargs -r wipefs --no-act

echo
echo "OK: disko target did not report tank/ssd labels."
echo "Continue only if the target is the old boot disk and not a data-pool member."
```

The expected result is that ZFS labels on the disko target identify the old boot
pool or no data pool at all. If `tank` or `ssd` appears in the target label
dump, do not run disko.

## Pre-cutover checks

On TrueNAS, before shutdown:

```bash
zpool status
zpool list
midclt call service.query
midclt call pool.snapshottask.query
midclt call replication.query
incus list
incus storage list
incus network list
incus profile list
```

Confirm that current backups are acceptable before proceeding.

## Install NixOS

Boot a NixOS installer and run from `configs/nixos`:

```bash
# Only after the remote-only disko preflight above has passed.
nix run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  --flake .#nas

nixos-install --root /mnt --no-root-passwd --flake .#nas
```

Reboot into NixOS.

## First NixOS boot

Confirm pool import and health:

```bash
zpool status
zfs list
systemctl status zfs-import-tank.service zfs-import-ssd.service
```

Unlock encrypted datasets interactively:

```bash
zfs-unlock-encrypted-datasets
```

Confirm shares and health services:

```bash
testparm -s
exportfs -v
systemctl status samba-smbd nfs-server smartd netdata upsmon
systemctl list-timers 'sanoid*' 'zfs-scrub*' 'nas-replicate*'
nas-health-alert -s "NAS alert test" </dev/null
```

Create Samba passwords for users that should authenticate:

```bash
smbpasswd -a USERNAME
```

Validate SMB from clients, including Time Machine, photo/media access, guest
access to the guest-enabled share, and Previous Versions/shadow-copy browsing.

## Replication

Local replication is declared as `nas-replicate-ssd-local.timer`.

Remote replication services are declared but skip until their SSH keys exist:

```text
/etc/ssh/nas-replication-nuc-ed25519
/etc/ssh/nas-replication-hetzner-ed25519
```

Install the keys deliberately, restrict file mode to `0600`, verify SSH access,
then run:

```bash
systemctl start nas-replicate-ssd-to-nuc.service
systemctl start nas-replicate-hetzner-websites.service
```

Check the target datasets before enabling trust in the timers.

## Inbound backups

Other NixOS hosts may still push Syncoid backups to this machine. The `nas`
OpenSSH config allows key-only root login from the LAN for this purpose, but the
keys are intentionally not stored in this public repo.

After first boot, install the source host public keys in:

```text
/etc/ssh/authorized_keys.d/root
```

Use `from=` restrictions on each key where possible, keep the file mode at
`0600`, and reload SSH:

```bash
install -m 0600 -o root -g root /path/to/prepared-root-authorized-keys /etc/ssh/authorized_keys.d/root
systemctl reload sshd
```

For each pushing host, verify name resolution and host keys before trusting the
timer again:

```bash
ssh-keygen -R truenas.local
ssh root@truenas.local true
systemctl start zfs-replication.service
```

If `truenas.local` will no longer resolve to the NAS address in your network,
update the pushing hosts before the first post-cutover replication window.

## Incus

The NixOS config preseeds the Incus daemon storage pool, bridge, and default
profile. It does not copy container root filesystems.

The live Incus storage pool is on a data pool and is not touched by disko, but a
fresh NixOS boot has a fresh Incus database. Recover the existing volumes into
that database before applying the reconciler:

```bash
systemctl start incus.service
incus admin recover
nas-apply-incus-config
incus list
incus config show docker --expanded
incus config show nix-cache --expanded
incus config show nixos --expanded
```

Then start instances one at a time and validate their services.

If `incus admin recover` reports that storage-pool or instance metadata is
missing, stop and inspect the affected volume before starting containers.

## Tailscale

The TrueNAS Tailscale app is not migrated. NixOS runs host-level Tailscale.
Authenticate the host after first boot:

```bash
tailscale up
```

## Not migrated

- The stopped Actual Budget app is intentionally out of scope.
- The TrueNAS web UI is not recreated.
- iSCSI is not recreated.
