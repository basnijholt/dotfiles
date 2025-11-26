#!/usr/bin/env bash
# Migration Validation Script
# Compares Proxmox containers (via SSH) with Incus containers

set -euo pipefail

PROXMOX_HOST="hp"  # SSH alias or IP for Proxmox
INCUS_HOST="nuc"   # SSH alias or IP for NixOS/Incus host

# Container mappings: name:proxmox_id
declare -A CONTAINERS=(
    ["debian"]=107
    ["docker"]=128
    ["homepage"]=118
    ["meshcentral"]=126
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${YELLOW}--- $1 ---${NC}"
}

run_proxmox() {
    local ct_id=$1
    shift
    ssh "$PROXMOX_HOST" "pct exec $ct_id -- $*" 2>/dev/null || echo "(command failed or container stopped)"
}

run_incus() {
    local ct_name=$1
    shift
    ssh "$INCUS_HOST" "incus exec $ct_name -- $*" 2>/dev/null || echo "(command failed or container stopped)"
}

compare_container() {
    local name=$1
    local proxmox_id=$2

    print_header "Comparing: $name (Proxmox ID: $proxmox_id)"

    print_section "Listening Ports (ss -tlnp)"
    echo -e "${GREEN}[PROXMOX]${NC}"
    run_proxmox "$proxmox_id" ss -tlnp 2>/dev/null | grep LISTEN || echo "(none)"
    echo -e "\n${GREEN}[INCUS]${NC}"
    run_incus "$name" ss -tlnp 2>/dev/null | grep LISTEN || echo "(none)"

    print_section "Disk Usage (df -h /)"
    echo -e "${GREEN}[PROXMOX]${NC}"
    run_proxmox "$proxmox_id" df -h / 2>/dev/null | tail -1
    echo -e "${GREEN}[INCUS]${NC}"
    run_incus "$name" df -h / 2>/dev/null | tail -1

    print_section "Running Processes (ps aux --no-headers | wc -l)"
    echo -e "${GREEN}[PROXMOX]${NC} $(run_proxmox "$proxmox_id" "ps aux --no-headers | wc -l") processes"
    echo -e "${GREEN}[INCUS]${NC} $(run_incus "$name" "ps aux --no-headers | wc -l") processes"

    print_section "Home Directories"
    echo -e "${GREEN}[PROXMOX]${NC}"
    run_proxmox "$proxmox_id" "ls -la /home 2>/dev/null" || echo "(empty or doesn't exist)"
    echo -e "\n${GREEN}[INCUS]${NC}"
    run_incus "$name" "ls -la /home 2>/dev/null" || echo "(empty or doesn't exist)"

    print_section "Enabled Systemd Services (top 15)"
    echo -e "${GREEN}[PROXMOX]${NC}"
    run_proxmox "$proxmox_id" "systemctl list-unit-files --state=enabled --type=service --no-pager 2>/dev/null" | head -15
    echo -e "\n${GREEN}[INCUS]${NC}"
    run_incus "$name" "systemctl list-unit-files --state=enabled --type=service --no-pager 2>/dev/null" | head -15

    # Docker-specific checks
    if [[ "$name" == "docker" ]]; then
        print_section "Docker Containers"
        echo -e "${GREEN}[PROXMOX]${NC}"
        run_proxmox "$proxmox_id" "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "(docker not running)"
        echo -e "\n${GREEN}[INCUS]${NC}"
        run_incus "$name" "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "(docker not running)"
    fi

    print_section "Network Connectivity Test"
    echo -e "${GREEN}[INCUS]${NC} ping 8.8.8.8:"
    run_incus "$name" "ping -c1 -W2 8.8.8.8 2>&1" | grep -E "bytes from|100% packet loss" || echo "(ping failed)"
}

# Main
echo -e "${BLUE}Migration Validation Script${NC}"
echo "Proxmox host: $PROXMOX_HOST"
echo "Incus host: $INCUS_HOST"
echo "Containers to validate: ${!CONTAINERS[*]}"

for name in "${!CONTAINERS[@]}"; do
    compare_container "$name" "${CONTAINERS[$name]}"
done

print_header "Validation Complete"
echo "Review the output above for any discrepancies between Proxmox and Incus containers."
