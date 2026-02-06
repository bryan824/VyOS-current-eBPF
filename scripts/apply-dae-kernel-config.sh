#!/bin/bash
# ============================================================================
# Apply dae Kernel Configuration to VyOS Current Branch
# ============================================================================
# This script modifies vyos_defconfig by appending dae configurations.
# Run from repository root after checkout.
#
# Usage: ./apply-dae-kernel-config.sh
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Apply dae Kernel Configuration${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# File paths
KERNEL_CONFIG="vyos-build/scripts/package-build/linux-kernel/arch/x86/configs/vyos_defconfig"
DAE_CONFIG="vyos-dae-kernel/configs/kernel-dae.config"

# Verify files exist
echo "Checking files..."
if [ ! -f "$KERNEL_CONFIG" ]; then
    echo -e "${RED}ERROR: $KERNEL_CONFIG not found${NC}"
    echo "Current directory: $(pwd)"
    echo "Expected structure:"
    echo "  ./vyos-build/scripts/package-build/linux-kernel/arch/x86/configs/vyos_defconfig"
    echo "  ./vyos-dae-kernel/configs/kernel-dae.config"
    exit 1
fi

if [ ! -f "$DAE_CONFIG" ]; then
    echo -e "${RED}ERROR: $DAE_CONFIG not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Files found"

# Create build log directory
mkdir -p vyos-build/build

# Backup
echo ""
echo "Creating backup..."
cp "$KERNEL_CONFIG" "${KERNEL_CONFIG}.original"
echo -e "${GREEN}✓${NC} Backup: ${KERNEL_CONFIG}.original"

# Apply configuration
echo ""
echo "Injecting dae configurations..."

cat >> "$KERNEL_CONFIG" << 'HEADER'

################################################################################
# dae eBPF/BTF Support
################################################################################
# Added by: github.com/MaurUppi/vyos-dae-kernel
# Required for: dae transparent proxy
################################################################################

HEADER

cat "$DAE_CONFIG" >> "$KERNEL_CONFIG"

echo -e "${GREEN}✓${NC} dae configurations appended"

# Quick verification
echo ""
echo "Verifying critical configs..."

CRITICAL_CONFIGS=(
    "CONFIG_DEBUG_INFO_BTF=y"
    "CONFIG_KPROBES=y"
    "CONFIG_BPF_EVENTS=y"
    "CONFIG_KPROBE_EVENTS=y"
)

ALL_OK=true
for cfg in "${CRITICAL_CONFIGS[@]}"; do
    if grep -q "^${cfg}$" "$KERNEL_CONFIG"; then
        echo -e "${GREEN}✓${NC} $cfg"
    else
        echo -e "${RED}✗${NC} $cfg (missing)"
        ALL_OK=false
    fi
done

echo ""
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}✓ Configuration applied successfully${NC}"
    echo -e "${GREEN}============================================${NC}"
    exit 0
else
    echo -e "${RED}⚠ Some configurations missing${NC}"
    echo "Check configs/kernel-dae.config file"
    exit 1
fi