#!/bin/bash
# Activate DDS and system configuration for Autoware
#
# This script applies the sysctl and systemd configurations installed by autoware-config.
# Run this script after installing autoware-config to enable optimal DDS performance.
#
# Usage: sudo /usr/share/autoware/activate-dds-config.sh
#
# What this script does:
#   1. Reloads sysctl settings (enables high network buffer sizes)
#   2. Enables and starts multicast on loopback interface
#
# These settings are required for CycloneDDS to work efficiently with large messages
# (e.g., point clouds, camera images).

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# =============================================================================
# Step 1: Apply sysctl settings
# =============================================================================
log_info "Applying sysctl settings..."

if [ -f /etc/sysctl.d/10-cyclone-max.conf ]; then
    sysctl --system > /dev/null 2>&1
    log_info "Sysctl settings applied:"
    echo "  net.core.rmem_max=$(sysctl -n net.core.rmem_max)"
    echo "  net.ipv4.ipfrag_time=$(sysctl -n net.ipv4.ipfrag_time)"
    echo "  net.ipv4.ipfrag_high_thresh=$(sysctl -n net.ipv4.ipfrag_high_thresh)"
else
    log_warn "Sysctl config not found. Is autoware-config installed?"
fi

# =============================================================================
# Step 2: Enable multicast on loopback
# =============================================================================
log_info "Enabling multicast on loopback..."

if [ -f /etc/systemd/system/multicast-lo.service ]; then
    # Check if systemd is available (not in Docker containers usually)
    if command -v systemctl &> /dev/null && [ -d /run/systemd/system ]; then
        systemctl daemon-reload
        systemctl enable multicast-lo.service 2>/dev/null || true
        systemctl start multicast-lo.service 2>/dev/null || true
        log_info "multicast-lo.service enabled and started"
    else
        # Direct approach for containers or systems without systemd
        log_warn "systemd not available, applying multicast directly..."
        ip link set lo multicast on 2>/dev/null || true
    fi
else
    log_warn "multicast-lo.service not found. Is autoware-config installed?"
fi

# Verify multicast is enabled
if ip link show lo | grep -q "MULTICAST"; then
    log_info "Loopback multicast: ENABLED"
else
    log_warn "Loopback multicast: NOT ENABLED"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
log_info "DDS configuration activated!"
echo ""
echo "You can verify the configuration with:"
echo "  sysctl net.core.rmem_max net.ipv4.ipfrag_time net.ipv4.ipfrag_high_thresh"
echo "  ip link show lo | grep MULTICAST"
echo ""
