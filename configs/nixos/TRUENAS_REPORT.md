# TrueNAS SCALE Incident Report
## System Outage - 2026-01-14

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Incident Start** | 2026-01-14 03:00:29 |
| **Power Cycle** | 2026-01-14 ~12:12 |
| **Duration** | ~9 hours |
| **Root Cause** | OOM (Out of Memory) death spiral |
| **Data Loss** | None - all ZFS pools healthy |
| **Contributing Factor** | 104 Docker containers without memory limits; no swap (TrueNAS design) |

---

## 1. System Configuration

### Hardware Specifications

| Component | Details |
|-----------|---------|
| **CPU** | Intel Core i5-13500T (13th Gen), 14 cores / 20 threads |
| **RAM** | 64GB DDR5-4800 (2x32GB Corsair), No ECC |
| **Swap** | **NONE CONFIGURED** (Critical Issue) |
| **Boot Drive** | Samsung 970 EVO 500GB NVMe (nvme1) |
| **SSD Pool** | 2x Samsung 990 EVO Plus 4TB NVMe (mirror) |
| **HDD Pool** | 8x WD Ultrastar 14-16TB (RAIDZ2, ~90TB usable) |
| **NICs** | 2x Intel I226 2.5GbE |

### Software Stack

| Layer | Details |
|-------|---------|
| **OS** | TrueNAS SCALE 24.04.2 (Debian 12 Bookworm) |
| **Kernel** | 6.12.33-production+truenas |
| **Virtualization** | Incus (LXC containers) |
| **Container Runtime** | Docker (inside LXC) |

### LXC Containers (Incus)

| Name | IP | Purpose |
|------|------|---------|
| **nixos** | 192.168.1.6 | Primary workload - runs 104 Docker containers |
| **docker** | 192.168.1.161 | Secondary Docker host |
| **nix-cache** | 192.168.1.145 | Nix binary cache |

### Docker Containers (inside nixos LXC)

**Total: 104 containers**

Key services include:
- **Media Stack**: Jellyfin, Sonarr, Radarr, Lidarr, Prowlarr, Jackett, qBittorrent, SABnzbd
- **Nextcloud AIO**: 10+ containers (apache, nextcloud, database, redis, collabora, etc.)
- **Paperless-ngx**: Document management with Celery workers
- **Home Automation**: go2rtc, Frigate (likely)
- **Development**: Gitea runners (4x), Traefik, various custom apps
- **Monitoring**: Prometheus, Glances, Netdata, Dozzle
- **Misc**: LibreChat, Syncthing, Guacamole, Headscale, etc.

### ZFS Pool Configuration

```
POOL       LAYOUT    DRIVES    SIZE      STATUS
boot-pool  single    1 NVMe    500GB     ONLINE, healthy
ssd        mirror    2 NVMe    4TB       ONLINE, healthy
tank       raidz2    8 HDD     ~120TB    ONLINE, healthy
```

---

## 2. Incident Timeline

### Memory Pressure Events: 978 total

### OOM Kill Events: 200+ processes killed

```
TIMELINE:
03:00:29 - First "Under memory pressure, flushing caches"
03:00:37 - First OOM kill: gpg-agent
03:00:52 - systemd killed in nixos container
03:02:35 - immich killed
03:32:55 - qbittorrent-nox killed
03:57:34 - jellyfin killed
   ...
10:39:26 - tailscaled killed
10:41:20 - python killed
10:42:30 - go.d.plugin (netdata) killed
10:42:38 - tailscaled killed (again)
10:43:25 - tailscaled killed (again)
10:43:52 - traefik killed
10:44:31 - celery killed
10:45:14 - php-fpm killed
10:46:42 - wakapi killed
10:52:30 - python killed
10:54:01 - celery killed
10:57:33 - php-fpm killed
10:59:40 - granian killed
11:01:18 - autobrr killed
11:12:51 - python3 killed
11:13:51 - python killed
11:27:57 - midclt (TrueNAS middleware) killed x4
11:27:57 - nut-monitor, cron, wsdd killed
11:33:01 - celery killed
11:35:12 - celery killed
11:35:15 - celery beat killed
11:36:14 - celery killed
11:37:05 - celery killed
11:48:24 - granian killed
11:53:14 - celery killed
11:53:24 - python3 killed
11:55:55 - celery killed
11:58:49 - nicotine killed
11:58:59 - go2rtc killed
12:09:32 - midclt killed
12:09:44 - celery killed (LAST OOM KILL)
~12:12   - USER POWER CYCLED VIA INTEL AMT
```

### Killed Process Summary

| Process | Approx. Kills | Container/Service |
|---------|--------------|-------------------|
| celery / celeryd | 15+ | paperless-ngx |
| python / python3 | 10+ | Various |
| tailscaled | 5+ | Multiple instances |
| php-fpm | 3+ | Nextcloud |
| granian | 2+ | ASGI server |
| midclt | 5+ | TrueNAS middleware |
| go.d.plugin | 2+ | Netdata |
| jellyfin | 1+ | Media server |
| immich | 1+ | Photo management |
| traefik | 1+ | Reverse proxy |
| qbittorrent | 1+ | Torrent client |
| go2rtc | 1+ | Media streaming |
| nicotine | 1+ | Soulseek client |
| autobrr | 1+ | Torrent automation |
| systemd | 1+ | Init system (in container) |

---

## 3. Root Cause Analysis

### Primary Cause: Container Memory Usage Without Limits

```
Configuration at crash time:
  Total RAM:           64 GB
  Docker Containers:   104 (no memory limits set)
  Swap:                None (TrueNAS by design)
  ZFS ARC Max:         61.5 GB (default, but shrinks under pressure)
```

**Impact**: 104 Docker containers running without memory limits. When containers consume all available RAM, and with no swap to buffer, OOM killer triggers immediately. Containers respawn, consume memory again, triggering more OOM kills - a death spiral.

**Note**: ZFS ARC is configured to use up to 98% of RAM by default, but it *should* shrink under memory pressure. We don't have definitive proof ARC failed to shrink - the logs were too corrupted by memory pressure to preserve memory breakdown details.

### Contributing Factors

1. **Container Density**: 104 Docker containers in a single LXC
   - Each container has overhead
   - No memory limits configured on most containers
   - Celery workers spawn multiple processes

2. **Memory-Hungry Applications**:
   - Elasticsearch (tubearchivist): 1.2GB
   - Collabora (Nextcloud): 643MB
   - Tubearchivist: 656MB
   - LibreChat: 578MB
   - Paperless-ngx: 573MB + Celery workers
   - Dawarich: 364MB
   - Nicotine-plus: 323MB

3. **Respawn Loop**: OOM-killed processes auto-restarted (Docker restart policy), consuming more memory, triggering more OOM kills.

4. **Middle-of-Night Trigger**: First OOM at 03:00 suggests a scheduled job or memory leak reached critical mass.

### Memory Usage Snapshot (Post-Reboot)

Current container memory usage (top consumers):
```
CONTAINER                    MEM USAGE    % OF 64GB
archivist-es                 1.20 GiB     1.92%
tubearchivist                656 MiB      1.02%
nextcloud-aio-collabora      643 MiB      1.00%
LibreChat                    578 MiB      0.90%
paperless-ngx-webserver-1    573 MiB      0.89%
dawarich_app                 364 MiB      8.89% (4GB limit)
nicotine-plus                323 MiB      0.50%
guacamole_compose            287 MiB      0.45%
bazarr                       261 MiB      0.41%
waha                         257 MiB      0.40%
...
```

**Post-reboot total**: ~24GB active (36% of 64GB)

Before crash, memory usage was likely near 100% with no headroom.

---

## 4. PCIe Bus Errors

### Error Details

```
Device:    00:1a.0 - Intel Alder Lake-S PCH PCI Express Root Port #25
Chip:      [8086:7ac8]
Connected: 02:00.0 - Samsung NVMe SSD Controller PM9C1a [144d:a80d]
           (Samsung 990 EVO Plus 4TB - part of SSD mirror)

Error Types Observed:
  - RxErr (Physical Layer, Receiver Error)
  - BadDLLP (Data Link Layer Protocol Error)

Severity: Correctable (hardware is recovering)
Lane Error: Lane 2 of x4 link
```

### Sample Error Output
```
[  660.831938] pcieport 0000:00:1a.0: AER: Correctable error message received
[  660.831965] pcieport 0000:00:1a.0: PCIe Bus Error: severity=Correctable, type=Physical Layer
[  660.832745] pcieport 0000:00:1a.0:   device [8086:7ac8] error status/mask=00000001/00002000
[  660.833471] pcieport 0000:00:1a.0:    [ 0] RxErr                  (First)
[  661.002324] pcieport 0000:00:1a.0: AER: Correctable error message received
[  661.003327] pcieport 0000:00:1a.0:   device [8086:7ac8] error status/mask=00000080/00002000
[  661.004276] pcieport 0000:00:1a.0:    [ 7] BadDLLP
```

### Analysis

- Errors occur in bursts during boot (around 660-661 seconds uptime)
- Both Physical Layer (RxErr) and Data Link Layer (BadDLLP) errors present
- Lane 2 specifically flagged with errors
- "Correctable" means no data loss, but indicates signal integrity issues

### Potential Causes

1. **Loose M.2 connection** - Most common cause
2. **Marginal signal integrity** - Long traces, interference
3. **Thermal issues** - NVMe overheating (unlikely, temps are fine)
4. **BIOS/firmware bug** - PCIe power management issues
5. **Defective NVMe** - Early signs of hardware failure

---

## 5. Network Bridge Loop

### Error Details

```
br0: received packet on enp4s0 with own address as source address
     (addr:a8:b8:e0:04:49:de, vlan:0)

Rate: Hundreds of packets per 5 seconds (rate-limited)
```

### Bridge Configuration

```
Interface    State       Master   MAC Address
br0          UP          -        e6:a9:ef:92:a4:76 (virtual)
enp4s0       forwarding  br0      a8:b8:e0:04:49:de (physical)
vb-docker    forwarding  br0      02:10:e5:b8:f2:dd (LXC)
vb-debian    forwarding  br0      de:43:14:cb:c0:2f (LXC)
vethXXX      forwarding  br0      (various Docker interfaces)

STP State: ENABLED (1)
enp3s0: DOWN (not connected)
```

### Root Cause: Intel AMT MAC Address Pass-Through

**IDENTIFIED**: Intel AMT (out-of-band management) is sharing the same MAC address as the host NIC.

```
IP Address       MAC Address          Device
192.168.1.4      a8:b8:e0:04:49:de    enp4s0 (TrueNAS host)
192.168.1.201    a8:b8:e0:04:49:de    Intel AMT (management)
```

Evidence from tcpdump:
```
12:36:43.046629 a8:b8:e0:04:49:de > bc:24:11:e9:a3:40
  192.168.1.201.asf-rmcp > 192.168.1.15.59781: UDP
  (asf-rmcp = port 623 = IPMI/Intel AMT)
```

**What's happening:**
1. Intel AMT uses "MAC Address Pass-Through" (shares host NIC MAC)
2. When AMT sends traffic (to port 623/IPMI), it uses a8:b8:e0:04:49:de as source
3. Switch forwards/reflects this traffic
4. Linux bridge receives packets on enp4s0 with enp4s0's own MAC as source
5. Kernel logs warning: "received packet with own address as source"

**This is NOT a physical loop or switch misconfiguration.**

### Impact

- **Log spam**: Hundreds of warnings per minute (rate-limited)
- **CPU overhead**: Minimal - packets are simply dropped
- **Network stability**: Not affected - AMT traffic works fine
- **Not related to OOM issue**

### Solutions

**Option 1: Dedicated AMT MAC Address (Recommended)**
1. Reboot and enter Intel MEBx (Ctrl+P or F2 during POST)
2. Navigate to: Intel Management Engine → Network Setup
3. Find: "MAC Address" or "Dedicated MAC Address"
4. Enable dedicated MAC (different from host NIC)
5. Save and reboot

**Option 2: Move AMT to Different NIC**
1. Your second NIC (enp3s0) is currently unused
2. In MEBx, configure AMT to use the other NIC
3. Connect enp3s0 to network for out-of-band management

**Option 3: Suppress Kernel Warnings (Quick Fix)**
```bash
# This may have side effects on bridge filtering
echo 0 > /proc/sys/net/bridge/bridge-nf-call-arptables

# Make permanent via sysctl
echo "net.bridge.bridge-nf-call-arptables=0" >> /etc/sysctl.conf
```

**Option 4: Live with It**
- The warnings are harmless
- AMT functionality is not affected
- Just causes log noise

---

## 6. ZFS Recovery

### Import Duration

```
ix-zfs.service start:  2026-01-14 12:12:14
ix-zfs.service finish: 2026-01-14 12:26:24
Duration: 14 minutes 10 seconds
```

### Pool Status (Post-Recovery)

```
POOL       STATE   READ  WRITE  CKSUM  ERRORS
boot-pool  ONLINE  0     0      0      No known data errors
ssd        ONLINE  0     0      0      No known data errors
tank       ONLINE  0     0      0      No known data errors
```

### Analysis

- 14-minute import after unclean shutdown is within normal range for large pools
- ZFS had to replay the intent log (ZIL) and verify metadata
- All pools recovered with zero errors - excellent outcome
- Tank pool is large (~90TB raidz2) which explains longer import time

---

## 7. Temperature Status

All temperatures normal at time of report:

```
SENSOR                    TEMP      STATUS
CPU Package               47°C      OK (crit: 100°C)
CPU Core 0                36°C      OK
CPU Core 4                41°C      OK
CPU Core 8                46°C      OK
HDD sda                   42°C      OK (crit: 70°C)
HDD sdb                   42°C      OK
HDD sdc                   42°C      OK
HDD sdd                   39°C      OK
```

**Conclusion**: Thermal issues were NOT a factor in this incident.

---

## 8. Recommendations

### CRITICAL - Must Fix Immediately

#### 8.1 Set Container Memory Limits

**The primary issue**: 104 containers running without memory limits. When one leaks or spikes, it can consume all RAM.

**Priority containers to limit** (based on OOM kill frequency):

| Container | Suggested Limit | Why |
|-----------|-----------------|-----|
| paperless-ngx (celery workers) | 512MB-1GB per worker | Killed 15+ times |
| Nextcloud (php-fpm) | 2GB total | Killed 3+ times |
| Elasticsearch (archivist-es) | 2GB | Currently using 1.2GB |
| Collabora | 1GB | Currently using 643MB |
| LibreChat | 1GB | Currently using 578MB |
| Immich | 2GB | Killed during incident |
| Jellyfin | 2GB | Killed during incident |

**How to set limits in docker-compose.yml:**
```yaml
services:
  celery:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 256M
```

**For paperless-ngx specifically**, also reduce worker count:
```yaml
environment:
  PAPERLESS_TASK_WORKERS: 2  # Default may be higher
```

---

### HIGH PRIORITY

#### 8.2 Set Up Memory Monitoring

Add alerts to catch memory issues before they cause OOM:

**Using Netdata (already installed but crashed):**
- Configure alarm for memory usage > 80%
- Set critical alarm at 90%

**Using Prometheus (if configured):**
```yaml
- alert: HighMemoryUsage
  expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.80
  for: 5m
  annotations:
    summary: "Memory usage above 80%"
```

#### 8.3 Investigate 03:00 Trigger

First OOM occurred at 03:00:29 - check what scheduled job runs at that time:
```bash
# Check cron jobs
incus exec nixos -- crontab -l
incus exec nixos -- ls -la /etc/cron.d/

# Check systemd timers
incus exec nixos -- systemctl list-timers
```

A backup, scrub, or other scheduled task may have triggered the memory spike.

#### 8.4 Fix Intel AMT MAC Address Conflict

**Root cause identified**: Intel AMT shares MAC with host NIC, causing log spam.

**Recommended fix** (in Intel MEBx BIOS):
1. Reboot and press Ctrl+P during POST to enter MEBx
2. Navigate to: Network Setup → MAC Address
3. Enable "Dedicated MAC Address" (separate from host)
4. Save and exit

**Alternative**: Connect second NIC (enp3s0) and configure AMT to use it

---

### MEDIUM PRIORITY

#### 8.5 Reseat NVMe SSD

1. Power down TrueNAS
2. Open case
3. Remove Samsung 990 EVO Plus at M.2 slot for 02:00.0
4. Inspect for dust/debris
5. Reseat firmly
6. Verify thermal pad contact
7. Power up and monitor for PCIe errors

#### 8.6 (Optional) Limit ZFS ARC

**Note**: ARC *should* shrink under memory pressure. This is a defensive measure if container limits alone don't prevent OOM.

**Current ARC config:**
```
ARC Max:     61.5 GiB (98.4% of RAM) - default
ARC Current: 23.1 GiB (post-reboot)
```

**To limit ARC (if needed):**

Go to **System → Advanced → Init/Shutdown Scripts**:
- Type: `Command`
- When: `Post Init`
- Command: `echo 34359738368 > /sys/module/zfs/parameters/zfs_arc_max`

This limits ARC to 32GB, guaranteeing ~28GB for containers.

#### 8.7 BIOS Settings Review

Check for:
- PCIe ASPM (Active State Power Management) - try disabling
- PCIe link speed settings - try forcing Gen3 or Gen4
- Memory XMP profile - verify stable operation

#### 8.8 Reduce Container Count

Consider consolidating services:
- Multiple *arr apps could share resources better
- Gitea runners: do you need 4?
- Multiple Tailscale instances - consolidate?

---

## 9. Diagnostic Commands Reference

### Memory Analysis
```bash
# Current memory usage
free -h
cat /proc/meminfo

# Memory pressure events
grep "Under memory pressure" /var/log/messages | wc -l

# OOM kills
grep "Out of memory: Killed" /var/log/messages

# Container memory usage
incus exec nixos -- docker stats --no-stream
```

### PCIe Errors
```bash
# Current error counts
cat /sys/bus/pci/devices/0000:00:1a.0/aer_dev_correctable

# Real-time monitoring
dmesg -w | grep -i pcie

# Device identification
lspci -nn -s 00:1a.0 -vv
lspci -nn -s 02:00.0
```

### Network Bridge
```bash
# Bridge status
bridge link show
ip link show br0
cat /sys/class/net/br0/bridge/stp_state

# Watch for loop errors
dmesg -w | grep br0
```

### ZFS Status
```bash
# Pool health
zpool status -v

# Import time
journalctl -u ix-zfs.service -b

# Dataset usage
zfs list -o name,used,avail
```

### Containers
```bash
# LXC status
incus list

# Docker in nixos
incus exec nixos -- docker ps -a
incus exec nixos -- docker stats --no-stream
```

---

## 10. Post-Incident Checklist

- [ ] **CRITICAL**: Set memory limits on paperless-ngx celery workers (512MB-1GB each)
- [ ] **CRITICAL**: Set memory limits on top 10 memory-consuming containers
- [ ] Investigate what runs at 03:00 (first OOM trigger)
- [ ] Set up memory usage alerts (80% warn, 90% critical)
- [ ] Fix Intel AMT MAC conflict (configure dedicated MAC in MEBx)
- [ ] Reseat NVMe SSD at 02:00.0
- [ ] Check BIOS for PCIe ASPM settings
- [ ] (Optional) Limit ZFS ARC if container limits alone don't help
- [ ] Consider enabling journald persistent logging for better forensics
- [ ] Monitor for PCIe errors over next 7 days

---

## 11. Appendix

### A. Full Hardware Inventory

```
PCIe Devices:
00:00.0 Host bridge: Intel Corporation Device [8086:4640]
00:02.0 VGA: Intel AlderLake-S GT1 [8086:4680]
00:06.0 PCI bridge: Intel 12th Gen x4 Controller [8086:464d]
00:14.0 USB: Intel Alder Lake USB 3.2 Gen 2x2 [8086:7ae0]
00:16.0 Communication: Intel HECI Controller [8086:7ae8]
00:17.0 SATA: Intel Alder Lake AHCI [8086:7ae2]
00:1a.0 PCI bridge: Intel PCIe Root Port #25 [8086:7ac8] ← ERROR SOURCE
00:1c.0 PCI bridge: Intel PCIe Root Port #1 [8086:7ab8]
00:1c.1 PCI bridge: Intel PCIe Root Port #2 [8086:7ab9]
00:1c.4 PCI bridge: Intel PCIe Root Port #5 [8086:7abc]
00:1f.0 ISA bridge: Intel Device [8086:7a83]
00:1f.3 Audio: Intel Alder Lake HD Audio [8086:7ad0]
00:1f.4 SMBus: Intel Alder Lake SMBus [8086:7aa3]
01:00.0 NVMe: Samsung 970 EVO 500GB [144d:a80d] (boot)
02:00.0 NVMe: Samsung 990 EVO Plus 4TB [144d:a80d] ← PCIE ERRORS
03:00.0 Ethernet: Intel I226-V 2.5GbE [8086:125c]
04:00.0 Ethernet: Intel I226-LM 2.5GbE [8086:125b]
```

### B. Disk Inventory

```
NAME       SIZE    MODEL                         SERIAL         POOL
nvme0n1    3.6TB   Samsung 990 EVO Plus 4TB     S7U8NJ0XA17725V  ssd (mirror)
nvme2n1    3.6TB   Samsung 990 EVO Plus 4TB     S7U8NJ0XA17834W  ssd (mirror)
nvme1n1    500GB   Samsung 970 EVO 500GB        S466NX0MC21160Z  boot-pool
sda        14.6TB  WDC WUH721816ALE604          3XGNJ16U         tank (raidz2)
sdb        14.6TB  WDC WUH721816ALE6L1          2CJ2AUJP         tank (raidz2)
sdc        14.6TB  WDC WUH721816ALE6L1          2CJ9XYEP         tank (raidz2)
sdd        16.4TB  WDC WUH721818ALE604          2MGAA7AJ         tank (raidz2)
sde        14.6TB  WDC WUH721816ALE604          3WKKDRNK         tank (raidz2)
sdf        14.6TB  WDC WUH721816ALE6L1          2BHP51EN         tank (raidz2)
sdg        14.6TB  WDC WUH721816ALE6L1          2CK41ENR         tank (raidz2)
sdh        16.4TB  WDC WUH721818ALE604          2MJ85KAJ         tank (raidz2)
```

### C. Network Configuration

```
Interface     Status  IP               MAC                Bridge
lo            UP      127.0.0.1        -                  -
enp3s0        DOWN    -                a8:b8:e0:04:49:dd  -
enp4s0        UP      -                a8:b8:e0:04:49:de  br0
br0           UP      192.168.1.4/24   e6:a9:ef:92:a4:76  -
vb-docker     UP      -                02:10:e5:b8:f2:dd  br0
vb-debian     UP      -                de:43:14:cb:c0:2f  br0
incusbr0      DOWN    10.44.217.1/24   10:66:6a:47:d4:1a  -
docker0       DOWN    172.16.0.1/24    a2:43:60:ba:07:03  -
tailscale0    UP      100.64.0.21/32   -                  -
```

---

*Report generated: 2026-01-14 12:45 PST*
*System: truenas.local (192.168.1.4)*
*TrueNAS SCALE 24.04.2*
