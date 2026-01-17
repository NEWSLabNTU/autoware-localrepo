#!/bin/bash
# Autoware 1.5.0 Uninstall Script
# Removes all Autoware packages installed from the local repository
#
# Usage: sudo /usr/share/autoware/uninstall-autoware.sh

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

log_info "Autoware 1.5.0 Uninstall Script"
echo ""

# Find all Autoware packages (with -1-5-0 suffix)
log_info "Finding installed Autoware packages..."
AUTOWARE_PKGS=$(dpkg -l | grep -E 'ros-humble-.*-1-5-0' | awk '{print $2}' || true)
META_PKGS=$(dpkg -l | grep -E '^ii\s+(autoware-config|autoware-theme|autoware-data|autoware-runtime|autoware-full)\s' | awk '{print $2}' || true)

# Combine and count packages
ALL_PKGS=$(echo -e "${AUTOWARE_PKGS}\n${META_PKGS}" | grep -v '^$' | sort -u)
PKG_COUNT=$(echo "$ALL_PKGS" | grep -c . || echo 0)

if [ "$PKG_COUNT" -eq 0 ]; then
    log_info "No Autoware packages found."
    exit 0
fi

echo ""
log_info "Found $PKG_COUNT Autoware packages to remove:"
echo "$ALL_PKGS" | head -20
if [ "$PKG_COUNT" -gt 20 ]; then
    echo "  ... and $((PKG_COUNT - 20)) more"
fi
echo ""

# Confirm removal
read -p "Remove all $PKG_COUNT Autoware packages? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Aborted."
    exit 0
fi

# Remove packages
log_info "Removing Autoware packages..."
echo "$ALL_PKGS" | xargs apt-get remove -y

# Clean up
log_info "Cleaning up..."
apt-get autoremove -y

echo ""
log_info "Autoware packages removed successfully!"
echo ""
log_warn "To complete the uninstallation, also remove the local repository package:"
echo "    sudo dpkg -r autoware-localrepo"
echo ""
log_warn "To remove the prerequisites (ROS2, CUDA libs), you may need to:"
echo "    sudo apt-get remove ros-humble-ros-base ros-humble-rmw-cyclonedds-cpp"
echo "    sudo apt-get remove libcudnn8 libnvinfer10 libnvinfer-plugin10 libnvonnxparsers10"
echo "    sudo dpkg -r cumm spconv"
echo ""
