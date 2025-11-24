# Proxmox to NixOS (Incus) Migration Guide

## 1. Goal
Migrate workloads (LXC Containers and KVM VMs) from a Proxmox host to a new NixOS host running **Incus**.

## 2. Inventory & Status

### LXC Containers (System Containers)
| ID | Name | Backup Status | Migration Status |
| :--- | :--- | :--- | :--- |
| 101 | `ubuntu` | ✅ Transferred (11GB) | ✅ **SUCCESS** (Running on `pc`) |
| 102 | `debian-stijn` | ✅ Transferred (225MB) | ✅ **SUCCESS** (Running on `pc`) |
| 107 | `debian` | ✅ Transferred (2.8GB) | ✅ **SUCCESS** (Running on `pc`) |
| 118 | `homepage` | ✅ Transferred (496MB) | ✅ **SUCCESS** (Running on `pc`) |
| 122 | `debian-wg` | ✅ Transferred (514MB) | ✅ **SUCCESS** (Running on `pc`) |
| 126 | `meshcentral` | ✅ Transferred (761MB) | ✅ **SUCCESS** (Running on `pc`) |
| 128 | `docker` | ✅ Transferred (5.3GB) | ✅ **SUCCESS** (Running on `pc`) |

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
4.  **Firewall:** Trust the bridge interface to allow DHCP/DNS traffic.
    *   Add `networking.firewall.trustedInterfaces = [ "incusbr0" ];` to `networking.nix`.

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
Since Proxmox backups are just rootfs tarballs, we create a fresh container and overwrite its filesystem directly from the archive. This method preserves permissions and handles complex files (like Docker layers) much better than extracting to a temporary directory.

1.  **Create Base Container:**
    Initialize a fresh container. Using `images:debian/12` is a safe default for most Linux containers as we will overwrite the OS anyway.
    ```bash
    incus init images:debian/12 my-container-name
    # Optional: Enable nesting if the container runs Docker
    incus config set my-container-name security.nesting true
    ```

2.  **Start Container:**
    The container must be running to execute the restore command inside it.
    ```bash
    incus start my-container-name
    ```

3.  **Stream Backup to Container:**
    We pipe the backup directly into the container's root (`/`), overwriting the template files.
    *Note: You may see "Operation not permitted" errors for `/proc` and `/sys`. These are safe to ignore.*
    ```bash
    zstdcat vzdump-lxc-101-*.tar.zst | incus exec my-container-name -- tar -x -C /
    ```

4.  **Verify & Reboot:**
    Check if the restore worked (e.g., check for your files in `/root`).
    ```bash
    incus exec my-container-name -- ls -la /root
    incus restart my-container-name
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
