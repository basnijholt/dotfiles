# Network Performance Report - 2025-12-20

## Network Topology

```
                        ┌─────────────┐
                        │   Internet  │
                        │ Ziply Fiber │
                        │   1 Gbps    │
                        └──────┬──────┘
                               │
                        ┌──────┴──────┐
                        │ Main Router │
                        │  ASUS XT8   │
                        │ 192.168.1.1 │
                        └──┬───┬───┬──┘
                           │   │   │
              ┌────────────┘   │   └────────────┐
              │                │                │
       ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
       │     hp      │  │   TrueNAS   │  │  XT8 Mesh   │
       │  (Ethernet) │  │  (Ethernet) │  │   Node      │
       │ 192.168.1.3 │  │ 192.168.1.4 │  │ (wireless   │
       └─────────────┘  └─────────────┘  │  backhaul)  │
                                         └──────┬──────┘
                                                │
                                         ┌──────┴──────┐
                                         │     pc      │
                                         │  (Ethernet) │
                                         │ 192.168.1.5 │
                                         └─────────────┘
```

## Machine Network Interfaces

### pc (NixOS)

| Interface | Type | IP Address | Link Speed |
|-----------|------|------------|------------|
| `enp5s0` | Ethernet | 192.168.1.5 | 1000 Mbps |
| `wlp7s0` | WiFi | 192.168.1.16 | N/A |

**Default route**: `enp5s0` (metric 100) preferred over `wlp7s0` (metric 600)

### hp (NixOS)

| Interface | Type | IP Address | Link Speed |
|-----------|------|------------|------------|
| `eno1` | Ethernet (bridged to `br0`) | 192.168.1.3 | 1000 Mbps |

### TrueNAS

| Host | IP Address |
|------|------------|
| `truenas` | 192.168.1.4 |
| `docker-lxc` (VM) | via TrueNAS |

## Internet Speed Tests (Ookla)

| Machine | Connection Path | Download | Upload | Latency | Status |
|---------|-----------------|----------|--------|---------|--------|
| **hp** | Ethernet → main router | 880 Mbps | 913 Mbps | 4.24 ms | ✅ Full speed |
| **docker-lxc** | VM → TrueNAS → main router | 921 Mbps | 916 Mbps | 4.18 ms | ✅ Full speed |
| **pc** | Ethernet → mesh node → wireless backhaul → main router | 545 Mbps | 594 Mbps | 7.88 ms | ⚠️ Limited by mesh |

## LAN Speed Tests (iperf3)

| Source | Destination | Speed | Notes |
|--------|-------------|-------|-------|
| hp → TrueNAS | Ethernet ↔ Ethernet | 933 Mbps | ✅ Near gigabit line rate |
| hp → pc | Ethernet ↔ mesh backhaul | 520 Mbps | WiFi mesh bottleneck |
| pc → hp | Mesh backhaul ↔ Ethernet | 751 Mbps | Good wireless backhaul performance |

## Key Findings

1. **Internet connection is healthy**: ~900 Mbps symmetric when tested from devices directly connected to the main router

2. **Mesh wireless backhaul is the bottleneck for pc**:
   - Raw backhaul speed: ~750 Mbps
   - Effective internet speed: ~550 Mbps (backhaul is shared for up/down)

3. **All Ethernet links operating at 1000 Mbps (gigabit)**

4. **No packet loss detected** on any path

## Recommendations

To achieve full gigabit on pc:

1. **Wired backhaul**: Run Ethernet cable between XT8 mesh node and main router
2. **Direct connection**: Connect pc directly to main router if physically possible

Current performance (~550-750 Mbps) is acceptable for most use cases if wired backhaul is not feasible.

## Commands Reference

```bash
# Restart NetworkManager connections
nmcli connection down "Wired connection 1" && nmcli connection up "Wired connection 1"
nmcli connection down "FeynLAN-5G" && nmcli connection up "FeynLAN-5G"

# Speed test (CLI)
nix-shell -p speedtest-cli --run speedtest
NIXPKGS_ALLOW_UNFREE=1 nix-shell -p ookla-speedtest --run 'speedtest --accept-license'

# LAN speed test (iperf3)
# Server: nix-shell -p iperf3 --run "iperf3 -s"
# Client: nix-shell -p iperf3 --run "iperf3 -c <server-ip>"

# Check default route
ip route | grep default

# Check interface link speed
cat /sys/class/net/<interface>/speed
nix-shell -p ethtool --run "ethtool <interface>"

# Temporarily disable firewall (NixOS with nftables)
sudo systemctl stop nftables
sudo systemctl start nftables
```
