# nas

NixOS host for the NAS services that used to run on TrueNAS.

Start with `PLANNING.md` for current migration status and handoff notes. Use
`CUTOVER.md` for the completed destructive cutover path and for future reinstall
reference.

This config is deliberately conservative:

- It imports existing data pools `tank` and `ssd` by name.
- Disko manages only the current TrueNAS boot-pool disk. It does not define a
  layout for the data pools.
- It reproduces the observed NFS paths, SMB share names, UPS client, bridge
  networking, UID/GID, SMART monitoring, ZFS event logging, and local reporting
  service surface.
- It enables Docker and Incus, preseeds Incus daemon storage/network/profile
  state, and provides a post-import helper for known Incus instances. Existing
  container root filesystems were recovered with `incus admin recover` during
  cutover and would need the same treatment after a future reinstall.
- Encrypted datasets are not unlocked at boot by this config. Run
  `zfs-unlock-encrypted-datasets` after boot and provide passphrases
  interactively, or deploy `zfs-unlock` as the off-box NixOS/OpenZFS successor
  to the old TrueNAS API unlock flow.
- Sanoid approximates the local snapshot cadence. Existing non-Sanoid snapshots
  are preserved, replication services are declared separately, and Samba uses
  stock shadow-copy support for TrueNAS-style `auto-*` snapshots.
- iSCSI is intentionally not recreated because the old target/extent names were
  tied to the removed JB Weston setup.

Before reinstalling the real machine, read `CUTOVER.md`. Running disko for
`nas` destroys the boot disk.
