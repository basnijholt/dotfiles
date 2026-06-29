# NAS nixos-anywhere cutover commands

This is the short command-only path for the phased `nixos-anywhere` cutover.
The default all-in-one `nixos-anywhere` command is intentionally not used,
because it would run destructive disko without the manual installer preflight.

## Local prep

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

## Phase 1: kexec only

This boots the temporary NixOS installer over SSH. It should not run disko.

```bash
cd /home/basnijholt/dotfiles/configs/nixos

nix run github:nix-community/nixos-anywhere -- \
  --ssh-option UserKnownHostsFile=/dev/null \
  --ssh-option StrictHostKeyChecking=no \
  --flake .#nas \
  --target-host root@truenas \
  --phases kexec
```

After this returns, TrueNAS is no longer the running OS. If the next SSH does
not work, use AMT/console or find the installer DHCP address before proceeding.

## Installer preflight

Run this from your local machine after the `kexec` phase returns. It executes
inside the temporary installer over SSH and checks the same commit you built in
the local prep step.

```bash
set -euo pipefail

test -n "${NAS_COMMIT:-}"

ssh \
  -o UserKnownHostsFile=/dev/null \
  -o StrictHostKeyChecking=no \
  root@truenas \
  "EXPECTED_COMMIT='$NAS_COMMIT' nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git nixpkgs#zfs nixpkgs#util-linux nixpkgs#gptfdisk --command bash -s" <<'REMOTE_PREFLIGHT'
set -euo pipefail

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

Abort if the output is surprising. Before the `disko` phase, rebooting should
return to the untouched TrueNAS boot pool.

## Phase 2: destructive install

Only run this from your local machine after the installer preflight prints
`OK: preflight passed`.

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

## First boot checks

After the machine reboots into NixOS:

```bash
ssh basnijholt@nas

sudo zpool status
sudo zfs list
sudo systemctl status zfs-import-tank.service zfs-import-ssd.service

# One-time reconciliation for imported data pools if they mounted at /tank
# and /ssd instead of the TrueNAS-compatible /mnt paths used by services.
sudo zfs set mountpoint=/mnt/tank tank
sudo zfs set mountpoint=/mnt/ssd ssd
sudo zfs mount -a

sudo zfs-unlock-encrypted-datasets
sudo zfs mount -a
sudo systemctl restart nfs-server samba-smbd
sudo testparm -s
sudo exportfs -v
sudo systemctl status samba-smbd nfs-server smartd netdata upsmon
sudo systemctl list-timers 'sanoid*' 'zfs-scrub*' 'nas-replicate*'
```

Then do the manual service recovery:

```bash
sudo smbpasswd -a basnijholt
sudo smbpasswd -a marcella

sudo systemctl start incus.service
sudo incus admin recover
sudo nas-apply-incus-config
sudo incus list

sudo tailscale up
```

For `incus admin recover`, recover the existing ZFS storage pool as:

```text
storage pool: ssd
backend: zfs
source: ssd/.ix-virt
additional properties: leave empty
recover found volumes: yes
```

Use the ZFS dataset name `ssd/.ix-virt`, not `/mnt/ssd/.ix-virt`.

If an unprivileged recovered container fails with `newuidmap`/`newgidmap`, switch
the current `nas` config before retrying. The config declares the subordinate
UID/GID passthrough ranges used by the recovered instances.

Validate at least one NFS client before treating the storage side as complete.
From the PC, `findmnt -t nfs,nfs4` should show the expected `truenas.local`
exports resolving to the NAS address, and basic reads should succeed.

Install replication keys and alerting secrets from the cutover staging location
only as needed. Do not commit them to this repo.
