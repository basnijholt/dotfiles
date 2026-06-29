# NAS cutover runbook

This is the single canonical runbook for the TrueNAS to NixOS `nas` migration.
The real cutover completed on 2026-06-28 with the phased `nixos-anywhere` path.
Keep this file as the future reinstall/recovery reference.

## Safety Boundaries

- Disko manages only the boot disk and creates the NixOS `zroot`.
- The existing `tank` and `ssd` data pools are not described by disko.
- Do not run disko against any data-pool member device.
- Do not rely on physically unplugging data disks as a safety mechanism.
- Use out-of-band console access and the installer-side preflight before any destructive command.
- Run only one OS against the data pools at a time.
- Do not use the default all-in-one `nixos-anywhere` command.
  It would run `kexec,disko,install,reboot` without the manual preflight gate.

## Local Prep

Run from your local machine:

```bash
set -euo pipefail

cd /home/basnijholt/dotfiles/configs/nixos
git switch truenas-nixos-scaffold
git pull --ff-only

NAS_COMMIT="$(git rev-parse --short HEAD)"
printf 'Expected cutover commit: %s\n' "$NAS_COMMIT"

nix build --no-link --print-out-paths .#checks.x86_64-linux.nas-disko-safety
nix build --no-link --print-out-paths .#nixosConfigurations.nas.config.system.build.toplevel
```

You can also inspect the generated disko script before touching the machine:

```bash
script=$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.nas.config.system.build.diskoScript')
grep -oE '/dev/[^ "]*' "$script" | sort -u
```

The only real device path printed must be the boot disk by-id.
No `tank`/`ssd` member device may appear.

## Phase 1: Kexec Only

This boots a temporary NixOS installer over SSH.
It should not run disko.

```bash
cd /home/basnijholt/dotfiles/configs/nixos

nix run github:nix-community/nixos-anywhere -- \
  --ssh-option UserKnownHostsFile=/dev/null \
  --ssh-option StrictHostKeyChecking=no \
  --flake .#nas \
  --target-host root@truenas \
  --phases kexec
```

After this returns, TrueNAS is no longer the running OS.
If SSH does not come back on the expected address, use AMT/console or find the temporary installer's DHCP address before proceeding.
Do not run the destructive phase until the preflight below passes inside the temporary installer.

Before the `disko` phase, the disks have not been intentionally modified by this flow.
If the preflight looks wrong, abort and reboot back into TrueNAS.

## Installer Preflight

Run this from your local machine after the `kexec` phase returns.
It executes inside the temporary installer over SSH and checks the same commit built during local prep.

If the installer came up at a different address, replace `root@truenas` with the temporary installer address.

```bash
set -euo pipefail

test -n "${NAS_COMMIT:-}"

ssh \
  -o UserKnownHostsFile=/dev/null \
  -o StrictHostKeyChecking=no \
  root@truenas \
  "EXPECTED_COMMIT='$NAS_COMMIT' nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git nixpkgs#zfs nixpkgs#util-linux nixpkgs#gptfdisk --command bash -s" <<'REMOTE_PREFLIGHT'
set -euo pipefail
export NIX_CONFIG='experimental-features = nix-command flakes'

test -n "${EXPECTED_COMMIT:-}"

rm -rf /tmp/dotfiles
git clone https://github.com/basnijholt/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
git checkout truenas-nixos-scaffold
test "$(git rev-parse --short HEAD)" = "$EXPECTED_COMMIT"

cd configs/nixos

for cmd in nix readlink lsblk grep tee xargs; do
  command -v "$cmd" >/dev/null
done
command -v zpool >/dev/null
command -v zdb >/dev/null
command -v wipefs >/dev/null

modprobe zfs || true

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
zpool import || true

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

target_bytes="$(lsblk -bdno SIZE "$target_real")"
echo "DISKO TARGET SIZE: $target_bytes bytes"
if [ "$target_bytes" -ge 1000000000000 ]; then
  echo "STOP: disko target is >= 1 TB"
  exit 1
fi

echo
echo "Non-destructive signature check for disko target only:"
lsblk -nrpo NAME "$target_real" | xargs -r wipefs --no-act

echo
echo "OK: preflight passed"
REMOTE_PREFLIGHT
```

Abort on any surprising output.
The expected result is that the disko target is the old boot-pool disk, below the data-disk size guard, and has no `tank` or `ssd` ZFS labels.

## Phase 2: Destructive Install

Only run this from your local machine after the installer preflight prints `OK: preflight passed`.

If the installer came up at a different address, replace `root@truenas` with the same temporary installer address used for the preflight.

```bash
set -euo pipefail

test -n "${NAS_COMMIT:-}"

cd /home/basnijholt/dotfiles/configs/nixos
git switch truenas-nixos-scaffold
git pull --ff-only
test "$(git rev-parse --short HEAD)" = "$NAS_COMMIT"

nix run github:nix-community/nixos-anywhere -- \
  --ssh-option UserKnownHostsFile=/dev/null \
  --ssh-option StrictHostKeyChecking=no \
  --flake .#nas \
  --target-host root@truenas \
  --phases disko,install,reboot
```

This is the point of no return for the TrueNAS boot pool.

## USB/ISO Appendix

The phased `nixos-anywhere` path above is the path used for the real cutover.
For a future USB/ISO reinstall, shut down the previous OS cleanly, boot the installer, clone this repo, run the same installer preflight locally in the installer, and only then run:

```bash
nix run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  --flake .#nas

nixos-install --root /mnt --no-root-passwd --flake .#nas
```

## Secret Staging

Keep cutover-only secret material outside this repo.
A local `~/nas-cutover/` directory may exist, but do not commit it, copy it into this repo, paste its contents into logs, or read it from an agent session unless explicitly needed for the step being performed.

Expected secret material may include ZFS dataset passphrases, off-box unlock material, inbound replication authorized keys, outbound replication private keys, alerting config such as `nas-health-alert.env`, and one-time authentication notes.

## Encrypted Dataset Unlocks

The encrypted roots use ZFS passphrase keys.
The TrueNAS-era automatic unlock flow used `truenas-unlock` and the TrueNAS API from another device on the LAN.
The NixOS/OpenZFS successor is [`zfs-unlock`](https://github.com/basnijholt/zfs-unlock), which keeps the passphrases on another device and talks to a restricted NAS-side SSH receiver.

Until that receiver is configured on the NAS, unlock interactively after boot:

```bash
sudo zfs-unlock-encrypted-datasets
sudo zfs mount -a
sudo systemctl restart nfs-server samba-smbd
```

The helper discovers unavailable encrypted roots dynamically and does not hardcode private dataset names.
It prompts for passphrase-backed roots and skips legacy file keylocations that are not expected to exist on NixOS.

## First Boot Checks

After the machine reboots into NixOS:

```bash
ssh basnijholt@nas

sudo zpool status
sudo zfs list
sudo systemctl status zfs-import-tank.service zfs-import-ssd.service
```

The imported data pools are not created by disko.
Confirm their ZFS `mountpoint` properties match the paths used by NFS, SMB, and Incus:

```bash
sudo zfs get mountpoint tank ssd
```

If they mounted at `/tank` and `/ssd`, reconcile the persistent ZFS properties once:

```bash
sudo zfs set mountpoint=/mnt/tank tank
sudo zfs set mountpoint=/mnt/ssd ssd
sudo zfs mount -a
sudo systemctl restart nfs-server samba-smbd
```

Confirm shares and health services:

```bash
sudo testparm -s
sudo exportfs -v
sudo systemctl status samba-smbd nfs-server smartd netdata upsmon
sudo systemctl list-timers 'sanoid*' 'zfs-scrub*' 'nas-replicate*'
sudo nas-health-alert -s "NAS alert test" </dev/null
```

Create Samba passwords for users that should authenticate:

```bash
sudo smbpasswd -a USERNAME
```

Validate SMB from clients, including Time Machine, photo/media access, guest access to the guest-enabled share, and Previous Versions/shadow-copy browsing.

## Incus Recovery

The NixOS config can preseed the Incus daemon storage pool, bridge, and default profile on a fresh setup.
During this migration the ZFS storage dataset is already populated, so `incus-preseed.service` may fail before recovery.
The container root filesystems still live on the data pool.

Recover the existing volumes into the fresh Incus database before applying the reconciler:

```bash
sudo systemctl start incus.service
sudo incus admin recover
```

Use these recovery answers:

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

Use the ZFS dataset name `ssd/.ix-virt`, not a mounted filesystem path.
After recovery:

```bash
sudo nas-apply-incus-config
incus list
incus config show docker --expanded
incus config show nix-cache --expanded
incus config show nixos --expanded
```

Start instances one at a time and validate their services.

If an unprivileged recovered instance fails with `newuidmap` or `newgidmap`, confirm `/etc/subuid` and `/etc/subgid` include both Incus's shifted range and the explicit passthrough IDs, then switch to the current `nas` config before starting it again.

## Replication

Local replication is declared as `nas-replicate-ssd-local.timer`.

Remote replication services are declared but skip until their SSH keys exist:

```text
/etc/ssh/nas-replication-nuc-ed25519
/etc/ssh/nas-replication-hetzner-ed25519
```

Install the private keys deliberately, restrict file mode to `0600`, and authorize the matching public key on each remote before first run.
Verify SSH access with `BatchMode=yes`, then run:

```bash
sudo systemctl start nas-replicate-ssd-to-nuc.service
sudo systemctl start nas-replicate-hetzner-websites.service
```

Check source and target snapshots before trusting the timers.

## Inbound Backups

Other NixOS hosts may still push Syncoid backups to this machine.
The `nas` OpenSSH config allows key-only root login from the LAN for this purpose, but the keys are intentionally not stored in this public repo.

After first boot, install the source host public keys in:

```text
/etc/ssh/authorized_keys.d/root
```

Use `from=` restrictions on each key where possible, keep the file mode at `0600`, and reload SSH:

```bash
sudo install -m 0600 -o root -g root /path/to/prepared-root-authorized-keys /etc/ssh/authorized_keys.d/root
sudo systemctl reload sshd
```

For each pushing host, verify name resolution and host keys before trusting the timer again:

```bash
ssh-keygen -R truenas.local
ssh root@truenas.local true
systemctl start zfs-replication.service
```

Some hosts back up over sftp using a dedicated service account whose `authorized_keys` lives on a data pool.
For those, only name resolution and the new host key need attention on the client side.

## Client Validation

After NFS and SMB are up, validate clients from outside the NAS.
For the PC:

```bash
findmnt -t nfs,nfs4 -o TARGET,SOURCE,FSTYPE,OPTIONS
```

Confirm the mounts resolve to the NAS address and that read/write behavior matches the old TrueNAS exports.
The cutover validated the PC mounts for `/opt/stacks`, `/mnt/data`, and the expected `/mnt/tank/...` paths.

`truenas.local` remains a compatibility DNS name for existing clients.
`nas` and `nas.local` should also resolve to the NAS address.

Remove or disable client jobs that depended on the TrueNAS API, such as the old PC TrueNAS config-backup timer.

## Tailscale

The TrueNAS Tailscale app is not migrated.
NixOS runs host-level Tailscale.
Authenticate the host after first boot:

```bash
sudo tailscale up
```

## Not Migrated

- The stopped Actual Budget app is intentionally out of scope.
- The TrueNAS web UI is not recreated.
- iSCSI is not recreated.
