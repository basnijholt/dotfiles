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
- If using `nixos-anywhere`, do not run the default all-in-one phase sequence.
  Run `kexec` first, stop, run the disko preflight inside the temporary
  installer, then run `disko,install,reboot`.

## Boot disk

The NixOS boot layout is declared in `disko.nix`. The exact by-id device path is
intentionally not repeated in this public runbook.

Running disko for `nas` will destroy the existing TrueNAS boot pool on that
disk. The data pools are not described by disko and are imported by pool name.
Before running disko, compare the target in `disko.nix` with the installer
environment and confirm it is the boot-pool disk, not a data-pool member.

You can also prove this off-box, before booting the installer, by building the
exact script disko will run and listing every device it references:

```bash
script=$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.nas.config.system.build.diskoScript')
grep -oE '/dev/[^ "]*' "$script" | sort -u
```

The only real device path printed must be the boot disk by-id. No `tank`/`ssd`
member device may appear.

## Local disko rehearsal

Before cutover, run the VM rehearsal from `configs/nixos`:

```bash
nix build .#checks.x86_64-linux.nas-disko-safety
```

This boots a disposable NixOS VM with four throwaway disks, creates fake
`boot-pool`, `tank`, and `ssd` pools, runs the generated `nas` disko script
against the fake boot disk, then re-imports the fake data pools and checks
sentinel files. It does not connect to the live NAS.

This proves the generated disko script only formats the configured boot target
in that simulated disk topology. It does not replace the installer preflight:
the real cutover still depends on the by-id target resolving to the current
boot-pool disk on the actual machine.

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

# Size guard: the boot disk is ~500 GB; every data-pool member is >= 3.6 TB.
# Abort if the target is 1 TB or larger, which would mean it is a data disk.
target_bytes="$(lsblk -bdno SIZE "$target_real")"
echo "DISKO TARGET SIZE: $target_bytes bytes"
if [ "$target_bytes" -ge 1000000000000 ]; then
  echo "STOP: disko target is >= 1 TB; the boot disk should be ~500 GB"
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

## Secret staging directory

If using a local `~/nas-cutover/` directory prepared before migration, treat it
as the cutover-only staging area for secret material. Do not commit it, copy it
into this repo, paste its contents into logs, or read it from an agent session
unless explicitly needed for the cutover step being performed.

Expected secret material may include ZFS dataset passphrases or other off-box
unlock material, inbound replication authorized keys, outbound replication
private keys, alerting configuration such as `nas-health-alert.env`, and any
one-time authentication notes needed after first boot.

During cutover, copy only the specific file needed for the current step into its
documented destination, set the documented ownership and mode, verify the
service, then leave the staging directory off-system or remove it once no
longer needed.

### Confirm encrypted dataset unlock material

The encrypted roots all use ZFS **passphrase** keys. The passphrases or unlock
material must be available off-box before shutdown. The current TrueNAS-era
automatic unlock flow is handled by `truenas-unlock` from another device on the
LAN; it does not commit keys to this repo.

Before shutting down, confirm the off-box unlock material and a manual recovery
path are available. NixOS will not have the TrueNAS API, so the existing
`truenas-unlock` flow does not carry over unchanged.

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

### Alternative: phased nixos-anywhere

`nixos-anywhere` can replace the USB/ISO boot path by kexecing the running
TrueNAS system into a temporary NixOS installer over SSH. This is convenient for
remote work, but the default `nixos-anywhere` phases are
`kexec,disko,install,reboot`, which would run destructive disko immediately
after the kexec.

Before using this path, confirm you have a fallback console path such as AMT in
case the temporary installer does not come back on the expected address. The
installer usually keeps the reachable network setup, but if it instead comes up
on DHCP you need another way to find or control it.

For this NAS, only use it in separated phases. Run from `configs/nixos`:

```bash
# Phase 1: boot the temporary NixOS installer over SSH.
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nas \
  --target-host root@truenas \
  --phases kexec
```

After this returns, TrueNAS is no longer the running OS. SSH back into the
temporary installer, fetch the exact repo state you intend to install, and run
the **Remote-only disko preflight** above:

```bash
ssh root@truenas

git clone https://github.com/basnijholt/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
git checkout truenas-nixos-scaffold
git rev-parse --short HEAD

cd configs/nixos
# Run the full preflight from this document before continuing.
```

Do not reboot between the two `nixos-anywhere` phases unless you are aborting or
starting over. A reboot from this point should boot the untouched TrueNAS boot
pool again, but you will need to re-run the `kexec` phase before continuing.

If `zpool`, `zdb`, or other preflight tools are missing from the kexec installer,
install them temporarily before running the preflight:

```bash
nix shell nixpkgs#zfs nixpkgs#util-linux nixpkgs#gptfdisk
```

Only if the preflight proves that the disko target is the old boot-pool disk and
does not contain `tank`/`ssd` labels, run the destructive phases from your local
machine:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nas \
  --target-host root@truenas \
  --phases disko,install,reboot
```

Run the second command from the same local branch/commit that you checked in the
temporary installer. The `nas` disko script is built from this flake and its
locked inputs; do not switch branches or update `flake.lock` between the
preflight and the destructive phases.

Do **not** run this for the NAS:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nas \
  --target-host root@truenas
```

That all-in-one form skips the manual installer preflight gate.

Before the `disko` phase, the disks have not been intentionally modified by this
flow. If the preflight looks wrong, abort and reboot back into TrueNAS. Kexec is
still not the same as a clean TrueNAS shutdown/export, so make the
backup/passphrase decision first, stop or quiesce write-heavy clients if needed,
and treat the `disko,install,reboot` command as the point of no return.

## First NixOS boot

Confirm pool import and health:

```bash
zpool status
zfs list
systemctl status zfs-import-tank.service zfs-import-ssd.service
```

The imported data pools are not created by disko. On first boot, confirm their
ZFS `mountpoint` properties match the TrueNAS-compatible paths used by NFS, SMB,
and Incus:

```bash
zfs get mountpoint tank ssd
```

If they mounted at `/tank` and `/ssd`, reconcile the persistent ZFS properties
once:

```bash
zfs set mountpoint=/mnt/tank tank
zfs set mountpoint=/mnt/ssd ssd
zfs mount -a
systemctl restart nfs-server samba-smbd
```

Unlock encrypted datasets interactively. Encrypted datasets and any shares backed
by them stay unavailable until unlocked:

```bash
zfs-unlock-encrypted-datasets
zfs mount -a
systemctl restart nfs-server samba-smbd
```

The helper discovers unavailable encrypted roots dynamically and does not
hardcode private dataset names. It prompts for passphrase-backed roots and skips
legacy file keylocations that are not expected to exist on NixOS.

These datasets do **not** auto-unlock on reboot under the current NixOS config.
After any restart, encrypted shares stay down until you unlock them manually. If
you want to preserve the hardware/network-presence behavior from
`truenas-unlock`, build a NixOS-native replacement after the first cutover.

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

Install the private keys deliberately, restrict file mode to `0600`, and
authorize the matching public key on each remote before first run: the NUC must
accept the push key, and the Hetzner host must accept the pull key. Verify SSH
access with `BatchMode=yes`, then run:

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

Some hosts instead back up over sftp using a dedicated service account whose
`authorized_keys` lives on a data pool, so those keys persist across the cutover.
For those, only name resolution and the new host key need attention on the
client side.

## Incus

The NixOS config can preseed the Incus daemon storage pool, bridge, and default
profile on a fresh setup. During this migration the ZFS storage dataset is
already populated, so `incus-preseed.service` may fail before recovery. That is
expected; the container root filesystems still live on the data pool.

The live Incus storage pool is on a data pool and is not touched by disko, but a
fresh NixOS boot has a fresh Incus database. Recover the existing volumes into
that database before applying the reconciler:

```bash
systemctl start incus.service
incus admin recover
```

Use the following recovery answers:

```text
Would you like to recover another storage pool? yes
Name of the storage pool: ssd
Name of the storage backend (dir, lvm, btrfs, zfs): zfs
Source of the storage pool (block device, volume group, dataset, path, ... as applicable): ssd/.ix-virt
Additional storage pool configuration property (KEY=VALUE, empty when done):
Would you like to recover another storage pool? no
Would you like to continue with scanning for lost volumes? yes
Would you like those to be recovered? yes
```

Use the ZFS dataset name `ssd/.ix-virt`, not a mounted filesystem path. After
recovery, apply the known instance settings and inspect the imported instances:

```bash
nas-apply-incus-config
incus list
incus config show docker --expanded
incus config show nix-cache --expanded
incus config show nixos --expanded
```

Then start instances one at a time and validate their services.

Unprivileged instances using `raw.idmap` also need host subordinate UID/GID
ranges for any explicit host IDs they map through. The `nas` config declares the
known passthrough IDs for the recovered instances. If an unprivileged instance
fails with `newuidmap` or `newgidmap`, confirm `/etc/subuid` and `/etc/subgid`
include both Incus's shifted range and the explicit passthrough IDs, then
`nixos-rebuild switch` to the current config before starting it again.

If `incus admin recover` reports that storage-pool or instance metadata is
missing, stop and inspect the affected volume before starting containers.

## Client validation

After NFS and SMB are up, validate clients from outside the NAS. For the PC
Docker host, the expected NFS mounts are:

```bash
findmnt -t nfs,nfs4 -o TARGET,SOURCE,FSTYPE,OPTIONS
```

Confirm the mounts resolve to the NAS address and that read/write behavior
matches the old TrueNAS exports. The cutover validated the PC mounts for
`/opt/stacks`, `/mnt/data`, and the expected `/mnt/tank/...` paths.

`truenas.local` remains a compatibility DNS name for existing clients. `nas` and
`nas.local` should also resolve to the NAS address; do not let the `.local`
wildcard point `nas.local` at a workload container.

Remove or disable any client jobs that depended on the TrueNAS API, such as the
old PC TrueNAS config-backup timer.

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
