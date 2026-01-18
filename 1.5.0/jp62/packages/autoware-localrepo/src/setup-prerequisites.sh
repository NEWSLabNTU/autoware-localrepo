#!/bin/bash
# Autoware 1.5.0 Prerequisites Setup Script
# This script installs all prerequisites needed before installing autoware-localrepo
#
# Usage: sudo ./setup-prerequisites.sh [OPTIONS]
#
# Options:
#   --install-cuda    Install NVIDIA CUDA/cuDNN/TensorRT libraries (skip prompt)
#   --no-cuda         Skip NVIDIA libraries installation (skip prompt)
#   -h, --help        Show this help message
#
# Prerequisites installed:
#   - ROS 2 Humble (ros-humble-ros-base + rmw-cyclonedds-cpp)
#   - (Optional) NVIDIA CUDA runtime libraries
#   - (Optional) TensorRT runtime libraries
#   - (Optional) SpConv/Cumm libraries

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Parse command line arguments
# =============================================================================
INSTALL_CUDA=""

show_help() {
    head -17 "$0" | tail -15
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --install-cuda)
            INSTALL_CUDA="y"
            shift
            ;;
        --no-cuda)
            INSTALL_CUDA="n"
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
if [ "$ARCH" != "amd64" ]; then
    log_error "This script is for amd64 architecture (detected: $ARCH)"
    exit 1
fi

log_info "Setting up Autoware 1.5.0 prerequisites on Ubuntu 22.04 (amd64)"

# =============================================================================
# Prompt for CUDA installation if not specified via command line
# =============================================================================
if [ -z "$INSTALL_CUDA" ]; then
    echo ""
    log_warn "Some Autoware components depend on NVIDIA CUDA, cuDNN, and TensorRT libraries."
    log_warn "These libraries have end-user license agreements that should be reviewed before installation."
    echo ""
    echo "  CUDA EULA:     https://docs.nvidia.com/cuda/eula/index.html"
    echo "  cuDNN SLLA:    https://docs.nvidia.com/deeplearning/cudnn/sla/index.html"
    echo "  TensorRT SLLA: https://docs.nvidia.com/deeplearning/tensorrt/sla/index.html"
    echo ""
    read -p "Install NVIDIA libraries? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_CUDA="y"
    else
        INSTALL_CUDA="n"
    fi
fi

# =============================================================================
# Step 0: Install required tools
# =============================================================================
log_info "Installing required tools..."
apt-get update
apt-get install -y curl wget gnupg lsb-release ca-certificates

# =============================================================================
# Step 1: ROS 2 Humble
# =============================================================================
log_info "Step 1/2: Installing ROS 2 Humble..."

if [ ! -f /usr/share/keyrings/ros-archive-keyring.gpg ]; then
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg
fi

if [ ! -f /etc/apt/sources.list.d/ros2.list ]; then
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu jammy main" > /etc/apt/sources.list.d/ros2.list
fi

apt-get update
apt-get install -y ros-humble-ros-base ros-humble-rmw-cyclonedds-cpp

log_info "ROS 2 Humble installed"

# =============================================================================
# Step 2: NVIDIA Libraries (optional)
# =============================================================================
if [ "$INSTALL_CUDA" = "y" ]; then
    log_info "Step 2/2: Installing NVIDIA libraries..."

    # Set up NVIDIA CUDA repository
    if [ ! -f /usr/share/keyrings/cuda-archive-keyring.gpg ]; then
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb \
            -O /tmp/cuda-keyring.deb
        dpkg -i /tmp/cuda-keyring.deb
        rm /tmp/cuda-keyring.deb
    fi

    # Install CUDA and TensorRT runtime libraries
    # Versions match Autoware 1.5.0 build environment (amd64.env)
    # Use --allow-change-held-packages for NVIDIA base images that hold some packages
    apt-get update
    apt-get install -y --allow-change-held-packages \
        libcudnn8=8.9.7.29-1+cuda12.2 \
        libnvinfer10=10.8.0.43-1+cuda12.8 \
        libnvinfer-plugin10=10.8.0.43-1+cuda12.8 \
        libnvonnxparsers10=10.8.0.43-1+cuda12.8 \
        libcublas-12-4 \
        libcurand-12-4 \
        libcusparse-12-4 \
        libcusolver-12-4 \
        libcufft-12-4

    # Hold packages to prevent automatic upgrades
    apt-mark hold libcudnn8 libnvinfer10 libnvinfer-plugin10 libnvonnxparsers10

    # Install SpConv and Cumm (for BEVFusion and other perception models)
    log_info "Installing SpConv and Cumm..."
    SPCONV_URL="https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu128"
    wget -q "${SPCONV_URL}/cumm_0.5.3_amd64.deb" -O /tmp/cumm.deb
    wget -q "${SPCONV_URL}/spconv_2.3.8_amd64.deb" -O /tmp/spconv.deb
    dpkg -i /tmp/cumm.deb /tmp/spconv.deb
    rm /tmp/cumm.deb /tmp/spconv.deb

    log_info "NVIDIA libraries installed"
else
    log_info "Step 2/2: Skipping NVIDIA libraries (not requested)"
    log_warn "Some Autoware perception components will not work without NVIDIA libraries."
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
echo "     sudo apt-get install autoware-full"
echo ""
echo "  2. Source the environment:"
echo "     source /opt/autoware/1.5.0/setup.bash"
echo ""
