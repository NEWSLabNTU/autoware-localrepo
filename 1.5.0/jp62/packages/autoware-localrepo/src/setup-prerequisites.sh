#!/bin/bash
# Autoware 1.5.0 Prerequisites Setup Script (JetPack 6.2)
# This script installs all prerequisites needed before installing autoware-localrepo
#
# Usage: sudo ./setup-prerequisites.sh [OPTIONS]
#
# Options:
#   --install-ros     Install ROS 2 Humble (skip prompt)
#   --no-ros          Skip ROS 2 installation (skip prompt)
#   --spconv          Install SpConv/Cumm libraries
#   --no-spconv       Skip SpConv/Cumm installation
#   -y, --yes         Answer yes to all prompts (ROS + SpConv)
#   -h, --help        Show this help message
#
# Prerequisites installed:
#   - ROS 2 Humble (ros-humble-ros-base + rmw-cyclonedds-cpp)
#   - (Optional) SpConv/Cumm libraries for perception models
#
# Note: JetPack 6.2 includes CUDA 12.6, cuDNN 9.3, and TensorRT 10.3 out of the box.
#       These do not need to be installed separately.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Handle Ctrl-C gracefully
trap 'echo ""; log_warn "Installation cancelled by user."; exit 1' INT

# Prompt for yes/no/quit - returns 0 for yes, 1 for no, exits on quit
prompt_ynq() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt [y/n/q]: " -n 1 -r response
        echo ""
        case "$response" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            [Qq]) log_warn "Installation cancelled by user."; exit 1 ;;
            *) echo "Please answer y (yes), n (no), or q (quit)." ;;
        esac
    done
}

# Prompt with yes as default (Enter = yes)
prompt_Ynq() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt [Y/n/q]: " -n 1 -r response
        echo ""
        case "$response" in
            [Yy]|"") return 0 ;;
            [Nn]) return 1 ;;
            [Qq]) log_warn "Installation cancelled by user."; exit 1 ;;
            *) echo "Please answer y (yes), n (no), or q (quit). Press Enter for yes." ;;
        esac
    done
}

# Prompt with no as default (Enter = no)
prompt_yNq() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt [y/N/q]: " -n 1 -r response
        echo ""
        case "$response" in
            [Yy]) return 0 ;;
            [Nn]|"") return 1 ;;
            [Qq]) log_warn "Installation cancelled by user."; exit 1 ;;
            *) echo "Please answer y (yes), n (no), or q (quit). Press Enter for no." ;;
        esac
    done
}

# =============================================================================
# Parse command line arguments
# =============================================================================
INSTALL_ROS=""
INSTALL_SPCONV=""
AUTO_YES=""  # Track if -y flag was used (skip all prompts)

show_help() {
    head -18 "$0" | tail -16
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --install-ros)
            INSTALL_ROS="y"
            shift
            ;;
        --no-ros)
            INSTALL_ROS="n"
            shift
            ;;
        --spconv)
            INSTALL_SPCONV="y"
            shift
            ;;
        --no-spconv)
            INSTALL_SPCONV="n"
            shift
            ;;
        -y|--yes)
            INSTALL_ROS="y"
            INSTALL_SPCONV="y"
            AUTO_YES="y"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# =============================================================================
# System checks
# =============================================================================

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "22.04" ]; then
        log_error "This script requires Ubuntu 22.04 (detected: $ID $VERSION_ID)"
        exit 1
    fi
else
    log_error "Cannot detect OS version"
    exit 1
fi

# Detect architecture
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" != "arm64" ]; then
    log_error "This script is for arm64/JetPack 6.2 (detected: $ARCH)"
    exit 1
fi

log_info "Setting up Autoware 1.5.0 prerequisites on JetPack 6.2 (arm64)"

# =============================================================================
# Interactive prompts (if not specified via command line)
# =============================================================================
echo ""
echo "=============================================="
echo "  Autoware 1.5.0 Prerequisites Setup"
echo "        (JetPack 6.2 / arm64)"
echo "=============================================="
echo ""
echo "This script will install prerequisites for Autoware."
echo "Press 'q' at any prompt or Ctrl-C to cancel."
echo ""
echo "Note: JetPack 6.2 includes CUDA, cuDNN, and TensorRT."
echo "      Only ROS 2 and SpConv need to be installed."
echo ""

# Prompt for ROS installation
if [ -z "$INSTALL_ROS" ]; then
    echo "ROS 2 Humble is required for Autoware."
    if prompt_Ynq "Install ROS 2 Humble?"; then
        INSTALL_ROS="y"
    else
        INSTALL_ROS="n"
    fi
    echo ""
fi

# Prompt for SpConv installation
if [ -z "$INSTALL_SPCONV" ]; then
    echo "SpConv/Cumm libraries are required for some perception models"
    echo "(BEVFusion, etc.)."
    if prompt_yNq "Install SpConv/Cumm?"; then
        INSTALL_SPCONV="y"
    else
        INSTALL_SPCONV="n"
    fi
    echo ""
fi

# Summary and confirmation
# Skip confirmation if -y flag was used
if [ "$AUTO_YES" != "y" ]; then
    while true; do
        echo "Installation plan:"
        echo "  - ROS 2 Humble: $([ "$INSTALL_ROS" = "y" ] && echo "Yes" || echo "No")"
        echo "  - SpConv/Cumm:  $([ "$INSTALL_SPCONV" = "y" ] && echo "Yes" || echo "No")"
        echo ""

        read -p "Proceed with installation? [Y/n/r(retry)/q]: " -n 1 -r
        echo ""
        case "$REPLY" in
            [Yy]|"") break ;;  # Continue with installation
            [Rr])
                # Reset and restart prompts
                INSTALL_ROS=""
                INSTALL_SPCONV=""
                exec "$0" "$@"
                ;;
            [Nn]|[Qq])
                log_warn "Installation cancelled by user."
                exit 0
                ;;
            *)
                echo "Please answer y (yes), n (no), r (retry), or q (quit)."
                ;;
        esac
    done
else
    # Auto-yes mode: show plan and proceed
    echo "Installation plan:"
    echo "  - ROS 2 Humble: $([ "$INSTALL_ROS" = "y" ] && echo "Yes" || echo "No")"
    echo "  - SpConv/Cumm:  $([ "$INSTALL_SPCONV" = "y" ] && echo "Yes" || echo "No")"
    echo ""
    echo "Proceeding with installation (auto-yes mode)..."
fi

echo ""

# =============================================================================
# Step 0: Install required tools
# =============================================================================
log_info "Installing required tools..."
apt-get update
apt-get install -y curl wget gnupg lsb-release ca-certificates

# =============================================================================
# Step 1: ROS 2 Humble (optional)
# =============================================================================
if [ "$INSTALL_ROS" = "y" ]; then
    log_info "Step 1/2: Installing ROS 2 Humble..."

    # Use ros2-apt-source package (recommended method)
    # See: https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debs.html
    if [ ! -f /etc/apt/sources.list.d/ros2.sources ]; then
        ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
        curl -L -o /tmp/ros2-apt-source.deb \
            "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.jammy_all.deb"
        dpkg -i /tmp/ros2-apt-source.deb
        rm /tmp/ros2-apt-source.deb
    fi

    apt-get update
    apt-get install -y ros-humble-ros-base ros-humble-rmw-cyclonedds-cpp

    log_info "ROS 2 Humble installed"
else
    log_info "Step 1/2: Skipping ROS 2 Humble (not requested)"
    log_warn "Autoware requires ROS 2 Humble. Install it manually if needed."
fi

# =============================================================================
# Step 2: SpConv/Cumm (optional)
# =============================================================================
if [ "$INSTALL_SPCONV" = "y" ]; then
    log_info "Step 2/2: Installing SpConv and Cumm..."
    SPCONV_URL="https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu128"

    # Create unique temporary files
    CUMM_DEB=$(mktemp /tmp/cumm.XXXXXX.deb)
    SPCONV_DEB=$(mktemp /tmp/spconv.XXXXXX.deb)

    # Download packages
    wget -q "${SPCONV_URL}/cumm_0.5.3_arm64-jetson.deb" -O "$CUMM_DEB" || {
        log_error "Failed to download cumm package"
        rm -f "$CUMM_DEB" "$SPCONV_DEB"
        exit 1
    }
    wget -q "${SPCONV_URL}/spconv_2.3.8_arm64-jetson.deb" -O "$SPCONV_DEB" || {
        log_error "Failed to download spconv package"
        rm -f "$CUMM_DEB" "$SPCONV_DEB"
        exit 1
    }

    # Install packages
    dpkg -i "$CUMM_DEB" "$SPCONV_DEB"
    rm -f "$CUMM_DEB" "$SPCONV_DEB"

    log_info "SpConv and Cumm installed"
else
    log_info "Step 2/2: Skipping SpConv/Cumm (not requested)"
    log_warn "Some perception models (BEVFusion, etc.) require SpConv."
fi

# =============================================================================
# Done
# =============================================================================
echo ""
log_info "Prerequisites installation complete!"
echo ""
echo "Next steps:"
echo "  1. Install Autoware:"
echo "     sudo apt-get update"
echo "     sudo apt-get install autoware-full-1-5-0"
echo ""
echo "  2. Source the environment:"
echo "     source /opt/autoware/1.5.0/setup.bash"
echo ""
