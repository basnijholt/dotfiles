# Proxmox to NixOS (Incus) Migration Guide

## 1. Goal
Migrate workloads (LXC Containers and KVM VMs) from a Proxmox host to a new NixOS host running **Incus**.

## 2. Inventory & Status

### LXC Containers (System Containers)
| ID | Name | Backup Status | Migration Status |
| :--- | :--- | :--- | :--- |
| 101 | `ubuntu` | ✅ Transferred (11GB) | Pending |
| 102 | `debian-stijn` | ✅ Transferred (225MB) | Pending |
| 107 | `debian` | ✅ Transferred (2.8GB) | Pending |
| 118 | `homepage` | ✅ Transferred (496MB) | ✅ **SUCCESS** (Running on `pc`) |
| 122 | `debian-wg` | ✅ Transferred (514MB) | Pending |
| 126 | `meshcentral` | ✅ Transferred (761MB) | ✅ **SUCCESS** (Running on `pc`) |
| 128 | `docker` | ✅ Transferred (5.3GB) | Pending |

### Virtual Machines (KVM)
| ID | Name | Backup Status | Migration Status |
| :--- | :--- | :--- | :--- |
| 100 | `haos` | Pending | Pending (Critical, UEFI) |
| 105 | `truenas-jbweston` | Pending | Pending |
| 108 | `nixos` | Pending | Pending |

---

## 3. Pre-Migration Prerequisites (NixOS Host)

1.  **Enable Incus:** Ensure `virtualisation.incus.enable = true;` is in your configuration.
2.  **Initialize Incus:**
    *   **Declarative:** Add `virtualisation.incus.preseed` to your config (recommended).
    *   **Imperative:** Run `sudo incus admin init` once.
3.  **User Permissions:** Add your user to the `incus-admin` group in `users.users.<name>.extraGroups`.
    *   *Tip:* Run `newgrp incus-admin` if you just added it.

---

## 4. Migration Workflow: LXC Containers

**Step A: Backup on Proxmox**
Run this on the Proxmox host (`ssh root@proxmox`):
```bash
# Replace 101 with Container ID
vzdump 101 --dumpdir /var/lib/vz/dump --mode suspend --compress zstd
```

**Step B: Transfer to NixOS**
Run this on the NixOS host:
```bash
scp root@proxmox:/var/lib/vz/dump/vzdump-lxc-101-*.tar.zst .
```

**Step C: Restore to Incus**
Since Proxmox backups are just rootfs tarballs without Incus metadata, we create an empty container and overwrite its filesystem.

1.  **Extract Backup:**
    ```bash
    mkdir -p restore_temp
    tar --use-compress-program=unzstd -xf vzdump-lxc-101-*.tar.zst -C restore_temp
    ```

2.  **Create Base Container:**
    Use a base image matching the source OS (e.g., `images:debian/12` or `images:ubuntu/22.04`).
    ```bash
    incus init images:debian/12 my-container-name
    ```

3.  **Push Root Filesystem:**
    Push the extracted files, overwriting the default template.
    ```bash
    # Iterate to avoid shell globbing issues if using sudo/sg
    for item in restore_temp/*; do
      incus file push -r -p "$item" my-container-name/
    done
    ```

4.  **Start Container:**
    ```bash
    incus start my-container-name
    ```

5.  **Verify & Cleanup:**
    ```bash
    incus list my-container-name
    rm -rf restore_temp
    ```

---

## 5. Migration Workflow: Virtual Machines

**Step A: Export Disk from Proxmox**
1.  Stop the VM on Proxmox.
2.  Locate the disk (e.g., `/dev/zvol/rpool/data/vm-100-disk-0`).
3.  Convert/Export to QCOW2:
    ```bash
    qemu-img convert -p -O qcow2 /dev/zvol/rpool/data/vm-100-disk-0 vm-100.qcow2
    ```

**Step B: Transfer to NixOS**
```bash
scp root@proxmox:~/vm-100.qcow2 .
```

**Step C: Import to Incus**
1.  **Initialize Empty VM:**
    ```bash
    incus init --vm --empty my-vm-name
    ```
2.  **Resize Disk (Optional):**
    If the source disk is larger than default (10GB), resize the Incus volume first.
    ```bash
    incus config device set my-vm-name root size=50GiB
    ```
3.  **Import Disk Image:**
    Use `incus-migrate` or write directly to the volume block device.
    *   *Direct Write (if using ZFS/LVM):* `qemu-img convert -O raw vm-100.qcow2 /dev/zvol/...`
    *   *Standard Import:*
        ```bash
        # This is the easiest generic method
        incus config device add my-vm-name root disk source=/absolute/path/to/vm-100.qcow2
        ```
        *Warning:* This attaches the file as a disk. For better performance, import it into the storage pool properly using `incus import`.

4.  **Start VM:**
    ```bash
    incus start my-vm-name
    incus console my-vm-name
    ```
