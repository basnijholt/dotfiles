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
We use a helper script `migrate-lxc.sh` to automate the restoration process. This script creates a fresh container, enables nesting (required for Docker), and streams the Proxmox backup directly into the running container to preserve permissions.

1.  **Run the Migration Script:**
    ```bash
    # Usage: ./migrate-lxc.sh <backup-file> <new-container-name>
    ./migrate-lxc.sh vzdump-lxc-101-*.tar.zst ubuntu
    ```

2.  **Verify:**
    The container will automatically restart. Check that it is running and accessible.
    ```bash
    incus list
    incus shell ubuntu
    ```

    *Note: You may see harmless errors during the script execution regarding `/proc`, `/sys`, or `/etc/machine-id`. These are expected when overwriting a live container's rootfs and can be 100% ignored.*

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
We use a helper script `migrate-vm.sh` to import the disk and create the VM.

1.  **Run the Migration Script:**
    This script imports the QCow2 disk into the Incus storage pool and creates a VM from it.
    ```bash
    # Usage: ./migrate-vm.sh <qcow2-file> <vm-name>
    ./migrate-vm.sh vm-100.qcow2 haos
    ```

    *Note: Since the disk is imported into the Incus storage pool, you can safely delete the original `.qcow2` file after verifying the VM works.*

2.  **Verify & Access:**
    The VM should be running. You can access its console to check boot progress.
    ```bash
    incus console haos
    # Press Ctrl+a, q to exit the console
    ```
