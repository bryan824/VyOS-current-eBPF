#!/bin/bash
# ============================================================================
# Copy Kernel Packages to VyOS Packages Directory
# ============================================================================
# This script copies the built kernel .deb packages to the packages/ directory
# where the VyOS ISO build process will automatically include them.
#
# Usage: ./copy-kernel-packages.sh
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Copy Kernel Packages${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Paths
KERNEL_BUILD_DIR="vyos-build/scripts/package-build/linux-kernel"
PACKAGES_DIR="vyos-build/packages"

# Create packages directory if not exists
mkdir -p "$PACKAGES_DIR"

# Find kernel packages
echo "Searching for kernel packages..."
echo ""

KERNEL_DEBS=$(find "$KERNEL_BUILD_DIR" -maxdepth 1 -name "linux-*.deb" -type f 2>/dev/null)

if [ -z "$KERNEL_DEBS" ]; then
    echo -e "${RED}ERROR: No kernel .deb packages found in ${KERNEL_BUILD_DIR}${NC}"
    echo ""
    echo "Directory contents:"
    ls -la "$KERNEL_BUILD_DIR"/*.deb 2>/dev/null || echo "  (no .deb files)"
    exit 1
fi

# Copy packages
echo "Found packages:"
COPIED=0
for deb in $KERNEL_DEBS; do
    filename=$(basename "$deb")
    
    # Skip debug packages (optional - they are large)
    if [[ "$filename" == *"-dbg_"* ]]; then
        echo -e "  ${YELLOW}⏭${NC} $filename (debug package, skipped)"
        continue
    fi
    
    cp "$deb" "$PACKAGES_DIR/"
    echo -e "  ${GREEN}✓${NC} $filename"
    COPIED=$((COPIED + 1))
done

echo ""

# Verify required packages
echo "Verifying required packages..."

REQUIRED_PATTERN="linux-image-*-vyos_*.deb"
if ls "$PACKAGES_DIR"/$REQUIRED_PATTERN 1>/dev/null 2>&1; then
    KERNEL_PKG=$(ls "$PACKAGES_DIR"/$REQUIRED_PATTERN | head -1)
    echo -e "${GREEN}✓${NC} Kernel image package found: $(basename "$KERNEL_PKG")"
else
    echo -e "${RED}✗${NC} Required kernel image package not found"
    echo ""
    echo "Expected pattern: $REQUIRED_PATTERN"
    echo "Available in packages/:"
    ls -la "$PACKAGES_DIR"/*.deb 2>/dev/null || echo "  (none)"
    exit 1
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✓ $COPIED package(s) copied to packages/${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# List final packages
echo "Packages ready for ISO build:"
ls -lh "$PACKAGES_DIR"/linux-*.deb 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}'
