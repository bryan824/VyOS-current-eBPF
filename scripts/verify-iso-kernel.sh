#!/bin/bash
# ============================================================================
# ISO Kernel Configuration Verification Script
# ============================================================================
# This script directly mounts the ISO and verifies kernel configurations
# without needing to boot the system in QEMU.
#
# Usage: ./verify-iso-kernel.sh <path-to-iso>
# ============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ISO_FILE="$1"
MOUNT_DIR="/tmp/vyos-iso-mount"
SQUASH_MOUNT="/tmp/vyos-squash-mount"

# Required kernel configs for dae
REQUIRED_CONFIGS=(
    "CONFIG_DEBUG_INFO_BTF=y"
    "CONFIG_KPROBES=y"
    "CONFIG_BPF_EVENTS=y"
    "CONFIG_KPROBE_EVENTS=y"
    "CONFIG_BPF=y"
    "CONFIG_BPF_SYSCALL=y"
    "CONFIG_BPF_JIT=y"
)

# Recommended configs
RECOMMENDED_CONFIGS=(
    "CONFIG_NET_CLS_BPF=m"
    "CONFIG_NET_ACT_BPF=m"
    "CONFIG_BPF_STREAM_PARSER=y"
    "CONFIG_LWTUNNEL_BPF=y"
    "CONFIG_CGROUP_BPF=y"
)

echo "============================================"
echo "  VyOS ISO Kernel Configuration Verifier"
echo "============================================"
echo ""

# Check if ISO file exists
if [ ! -f "$ISO_FILE" ]; then
    echo -e "${RED}✗ ISO file not found: $ISO_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} ISO file: $ISO_FILE"
echo -e "${GREEN}✓${NC} Size: $(du -h "$ISO_FILE" | cut -f1)"
echo ""

# Create mount points
sudo mkdir -p "$MOUNT_DIR"
sudo mkdir -p "$SQUASH_MOUNT"

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    sudo umount "$SQUASH_MOUNT" 2>/dev/null || true
    sudo umount "$MOUNT_DIR" 2>/dev/null || true
    sudo rmdir "$SQUASH_MOUNT" 2>/dev/null || true
    sudo rmdir "$MOUNT_DIR" 2>/dev/null || true
}

trap cleanup EXIT

# Mount ISO
echo "Mounting ISO..."
sudo mount -o loop "$ISO_FILE" "$MOUNT_DIR"
echo -e "${GREEN}✓${NC} ISO mounted at $MOUNT_DIR"
echo ""

# Find and mount squashfs
SQUASH_FILE="$MOUNT_DIR/live/filesystem.squashfs"

if [ ! -f "$SQUASH_FILE" ]; then
    echo -e "${RED}✗ SquashFS not found at expected location${NC}"
    exit 1
fi

echo "Mounting SquashFS..."
sudo mount -o loop "$SQUASH_FILE" "$SQUASH_MOUNT"
echo -e "${GREEN}✓${NC} SquashFS mounted at $SQUASH_MOUNT"
echo ""

# Find kernel config file
KERNEL_CONFIG=$(sudo find "$SQUASH_MOUNT/boot" -name "config-*" | head -1)

if [ -z "$KERNEL_CONFIG" ]; then
    echo -e "${RED}✗ Kernel config file not found${NC}"
    exit 1
fi

echo "Found kernel config: $(basename "$KERNEL_CONFIG")"
KERNEL_VERSION=$(basename "$KERNEL_CONFIG" | sed 's/config-//')
echo "Kernel version: $KERNEL_VERSION"
echo ""

# Verify required configurations
echo "============================================"
echo "  Verifying Required Configurations"
echo "============================================"
echo ""

REQUIRED_PASS=0
REQUIRED_FAIL=0

for config in "${REQUIRED_CONFIGS[@]}"; do
    if sudo grep -q "^${config}$" "$KERNEL_CONFIG"; then
        echo -e "${GREEN}✓${NC} $config"
        REQUIRED_PASS=$((REQUIRED_PASS+1))
    else
        echo -e "${RED}✗${NC} $config - MISSING"
        REQUIRED_FAIL=$((REQUIRED_FAIL+1))
    fi
done

echo ""
echo "Required: $REQUIRED_PASS passed, $REQUIRED_FAIL failed"
echo ""

# Verify recommended configurations
echo "============================================"
echo "  Verifying Recommended Configurations"
echo "============================================"
echo ""

RECOMMENDED_PASS=0
RECOMMENDED_FAIL=0

for config in "${RECOMMENDED_CONFIGS[@]}"; do
    if sudo grep -q "^${config}$" "$KERNEL_CONFIG"; then
        echo -e "${GREEN}✓${NC} $config"
        RECOMMENDED_PASS=$((RECOMMENDED_PASS+1))
    else
        echo -e "${YELLOW}⚠${NC} $config - Not enabled"
        RECOMMENDED_FAIL=$((RECOMMENDED_FAIL+1))
    fi
done

echo ""
echo "Recommended: $RECOMMENDED_PASS enabled, $RECOMMENDED_FAIL not enabled"
echo ""

# Check for BTF vmlinux
echo "============================================"
echo "  Additional Checks"
echo "============================================"
echo ""

# Check if BTF vmlinux would be available
if [ -f "$SQUASH_MOUNT/sys/kernel/btf/vmlinux" ] || sudo grep -q "CONFIG_DEBUG_INFO_BTF=y" "$KERNEL_CONFIG"; then
    echo -e "${GREEN}✓${NC} BTF support confirmed (CONFIG_DEBUG_INFO_BTF=y)"
else
    echo -e "${RED}✗${NC} BTF support not found"
fi

# Check kernel version
if [[ "$KERNEL_VERSION" =~ ^([0-9]+)\.([0-9]+) ]]; then
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}
    
    if [ "$MAJOR" -gt 5 ] || ([ "$MAJOR" -eq 5 ] && [ "$MINOR" -ge 17 ]); then
        echo -e "${GREEN}✓${NC} Kernel version $KERNEL_VERSION >= 5.17 (dae minimum requirement)"
    else
        echo -e "${RED}✗${NC} Kernel version $KERNEL_VERSION < 5.17 (dae requires >= 5.17)"
        REQUIRED_FAIL=$((REQUIRED_FAIL + 1))
    fi
fi

echo ""

# Generate JSON report
REPORT_FILE="/tmp/verification-report.json"

cat > "$REPORT_FILE" << EOF
{
  "iso_file": "$(basename "$ISO_FILE")",
  "iso_size": "$(stat -f%z "$ISO_FILE" 2>/dev/null || stat -c%s "$ISO_FILE")",
  "kernel_version": "$KERNEL_VERSION",
  "verification_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "required_configs": {
    "total": ${#REQUIRED_CONFIGS[@]},
    "passed": $REQUIRED_PASS,
    "failed": $REQUIRED_FAIL
  },
  "recommended_configs": {
    "total": ${#RECOMMENDED_CONFIGS[@]},
    "enabled": $RECOMMENDED_PASS,
    "disabled": $RECOMMENDED_FAIL
  },
  "overall_status": "$( [ $REQUIRED_FAIL -eq 0 ] && echo "PASS" || echo "FAIL" )"
}
EOF

echo "Verification report saved to: $REPORT_FILE"
echo ""

# Final result
echo "============================================"
echo "  Verification Summary"
echo "============================================"
echo ""

if [ $REQUIRED_FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} - All required configurations present"
    echo "This ISO has full dae eBPF support"
    echo ""
    exit 0
else
    echo -e "${RED}✗ FAIL${NC} - $REQUIRED_FAIL required configuration(s) missing"
    echo "This ISO may not support dae properly"
    echo ""
    exit 1
fi
