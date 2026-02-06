#!/bin/bash
# ============================================================================
# VyOS Kernel Configuration Verification for dae Support
# ============================================================================
# This script verifies that all required kernel configurations for dae are
# present and correctly enabled in the built kernel.
# 
# Exit codes:
#   0 - All checks passed
#   1 - One or more critical checks failed
#   2 - Script error (missing files, wrong environment, etc.)
# ============================================================================

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Check if running in CI environment
CI_MODE=${CI:-false}

# Print header
echo "=============================================="
echo "  dae Kernel Configuration Verification"
echo "=============================================="
echo ""

# ============================================================================
# Function: Check kernel version
# ============================================================================
check_kernel_version() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Kernel Version Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    KERNEL_VER=$(uname -r)
    MAJOR=$(echo "$KERNEL_VER" | cut -d. -f1)
    MINOR=$(echo "$KERNEL_VER" | cut -d. -f2)
    
    echo -n "Current kernel version: ${KERNEL_VER} ... "
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$MAJOR" -gt 5 ] || ([ "$MAJOR" -eq 5 ] && [ "$MINOR" -ge 17 ]); then
        echo -e "${GREEN}✓ PASS${NC}"
        echo "  → Meets minimum requirement (>= 5.17)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "  → Kernel version < 5.17 (dae requires >= 5.17)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
    echo ""
}

# ============================================================================
# Function: Find kernel config file
# ============================================================================
find_kernel_config() {
    CONFIG_FILE=""
    
    # Try different locations
    if [ -f /proc/config.gz ]; then
        CONFIG_FILE="/proc/config.gz"
        CONFIG_READER="zgrep"
    elif [ -f "/boot/config-$(uname -r)" ]; then
        CONFIG_FILE="/boot/config-$(uname -r)"
        CONFIG_READER="grep"
    elif [ -f /boot/config ]; then
        CONFIG_FILE="/boot/config"
        CONFIG_READER="grep"
    fi
    
    if [ -z "$CONFIG_FILE" ]; then
        echo -e "${RED}ERROR: Cannot find kernel config file${NC}"
        echo "Tried locations:"
        echo "  - /proc/config.gz"
        echo "  - /boot/config-$(uname -r)"
        echo "  - /boot/config"
        return 2
    fi
    
    echo "Using config file: ${CONFIG_FILE}"
    echo ""
}

# ============================================================================
# Function: Check a single kernel config option
# ============================================================================
check_config() {
    local key=$1
    local description=$2
    local required=${3:-true}  # true = critical, false = optional
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local value
    value=$($CONFIG_READER "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "")
    
    printf "  %-30s : " "$key"
    
    if [ "$value" == "y" ] || [ "$value" == "m" ]; then
        echo -e "[${GREEN}${value}${NC}] ✓ ${description}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [ "$required" == "true" ]; then
            echo -e "[${RED}MISSING${NC}] ✗ ${description} (CRITICAL)"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        else
            echo -e "[${YELLOW}MISSING${NC}] ⚠ ${description} (OPTIONAL)"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            return 0
        fi
    fi
}

# ============================================================================
# Function: Check all required kernel configurations
# ============================================================================
check_kernel_configs() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "2. Kernel Configuration Checks"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Critical configurations (must be enabled):"
    check_config "CONFIG_BPF" "BPF subsystem" true
    check_config "CONFIG_BPF_SYSCALL" "BPF system calls" true
    check_config "CONFIG_BPF_JIT" "BPF JIT compiler" true
    check_config "CONFIG_DEBUG_INFO_BTF" "BTF debug info (CRITICAL for dae)" true
    check_config "CONFIG_KPROBES" "Kernel probes" true
    check_config "CONFIG_KPROBE_EVENTS" "Kprobe events" true
    check_config "CONFIG_BPF_EVENTS" "BPF events" true
    check_config "CONFIG_NET_CLS_BPF" "BPF packet classifier" true
    check_config "CONFIG_NET_SCH_INGRESS" "Ingress Qdisc" true
    check_config "CONFIG_NET_INGRESS" "Ingress filtering" true
    check_config "CONFIG_NET_EGRESS" "Egress filtering" true
    check_config "CONFIG_CGROUPS" "Control groups" true
    check_config "CONFIG_BPF_STREAM_PARSER" "BPF stream parser" true
    
    echo ""
    echo "Additional configurations (recommended):"
    check_config "CONFIG_BPF_JIT_ALWAYS_ON" "BPF JIT always on" false
    check_config "CONFIG_NET_CLS_ACT" "Network classifier action" false
    check_config "CONFIG_CGROUP_BPF" "Cgroup BPF" false
    check_config "CONFIG_BPF_LSM" "BPF LSM" false
    
    echo ""
    echo "Verification of disabled options:"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local reduced_info
    reduced_info=$($CONFIG_READER "CONFIG_DEBUG_INFO_REDUCED" "$CONFIG_FILE" 2>/dev/null || echo "")
    
    printf "  %-30s : " "CONFIG_DEBUG_INFO_REDUCED"
    if echo "$reduced_info" | grep -q "is not set"; then
        echo -e "[${GREEN}NOT SET${NC}] ✓ Correctly disabled"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    elif [ -z "$reduced_info" ]; then
        echo -e "[${GREEN}NOT SET${NC}] ✓ Not present (OK)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "[${RED}ENABLED${NC}] ✗ Must be disabled for BTF"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    
    echo ""
}

# ============================================================================
# Function: Check runtime BTF availability
# ============================================================================
check_btf_runtime() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "3. Runtime BTF Verification"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "Checking /sys/kernel/btf/vmlinux ... "
    
    if [ -f /sys/kernel/btf/vmlinux ]; then
        local size
        size=$(stat -f %z /sys/kernel/btf/vmlinux 2>/dev/null || stat -c %s /sys/kernel/btf/vmlinux 2>/dev/null)
        echo -e "${GREEN}✓ EXISTS${NC}"
        echo "  → File size: ${size} bytes"
        echo "  → dae can load eBPF programs"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}✗ MISSING${NC}"
        echo "  → /sys/kernel/btf/vmlinux does not exist"
        echo "  → dae will NOT be able to start"
        echo "  → This is the most critical failure"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
    echo ""
}

# ============================================================================
# Function: Check additional system requirements
# ============================================================================
check_system_requirements() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "4. Additional System Checks"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check if bpftool is available
    echo -n "Checking bpftool availability ... "
    if command -v bpftool &> /dev/null; then
        echo -e "${GREEN}✓ AVAILABLE${NC}"
        bpftool version 2>/dev/null | head -1 || true
    else
        echo -e "${YELLOW}⚠ NOT FOUND${NC}"
        echo "  → bpftool is useful for debugging but not required"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    echo ""
    
    # Check if /sys/fs/bpf is mounted
    echo -n "Checking BPF filesystem mount ... "
    if mount | grep -q /sys/fs/bpf; then
        echo -e "${GREEN}✓ MOUNTED${NC}"
    else
        echo -e "${YELLOW}⚠ NOT MOUNTED${NC}"
        echo "  → Will be mounted automatically when needed"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    echo ""
}

# ============================================================================
# Function: Print summary
# ============================================================================
print_summary() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Verification Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Total checks performed: ${TOTAL_CHECKS}"
    echo -e "  ${GREEN}✓ Passed: ${PASSED_CHECKS}${NC}"
    
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "  ${RED}✗ Failed: ${FAILED_CHECKS}${NC}"
    fi
    
    if [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "  ${YELLOW}⚠ Warnings: ${WARNING_CHECKS}${NC}"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "${GREEN}✓✓✓ ALL CRITICAL CHECKS PASSED ✓✓✓${NC}"
        echo ""
        echo "This kernel is ready for dae!"
        echo ""
        echo "Next steps:"
        echo "  1. Install dae container image"
        echo "  2. Configure dae with your proxy settings"
        echo "  3. Start the dae container"
        echo ""
        return 0
    else
        echo -e "${RED}✗✗✗ CRITICAL CHECKS FAILED ✗✗✗${NC}"
        echo ""
        echo "This kernel is NOT ready for dae."
        echo ""
        echo "Most likely causes:"
        echo "  1. CONFIG_DEBUG_INFO_BTF=y was not enabled during compilation"
        echo "  2. CONFIG_KPROBES=y was not enabled"
        echo "  3. Kernel was compiled without debug info"
        echo ""
        echo "Solution:"
        echo "  - Use the pre-built ISO from:"
        echo "    https://github.com/MaurUppi/vyos-eBPF-kernel/releases/latest"
        echo ""
        return 1
    fi
}

# ============================================================================
# Main execution
# ============================================================================
main() {
    # Find kernel config file
    find_kernel_config || exit 2
    
    # Run all checks
    check_kernel_version
    check_kernel_configs
    check_btf_runtime
    check_system_requirements
    
    # Print summary and exit with appropriate code
    print_summary
    exit $?
}

# Run main function
main
