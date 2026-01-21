#!/bin/bash
# Autoware 1.5.0 Prerequisites Setup Script
# This script installs all prerequisites needed before installing autoware-localrepo
#
# Usage: sudo ./setup-prerequisites.sh [OPTIONS]
#
# Options:
#   --install-ros     Install ROS 2 Humble (skip prompt)
#   --no-ros          Skip ROS 2 installation (skip prompt)
#   --cuda            Install CUDA runtime libraries
#   --cudnn           Install cuDNN (requires CUDA)
#   --tensorrt        Install TensorRT (requires CUDA)
#   --spconv          Install SpConv/Cumm (requires CUDA)
#   --all-nvidia      Install all NVIDIA libraries
#   --no-nvidia       Skip all NVIDIA libraries
#   -y, --yes         Answer yes to all prompts (ROS + all NVIDIA)
#   -h, --help        Show this help message
#
# Prerequisites installed:
#   - ROS 2 Humble (ros-humble-ros-base + rmw-cyclonedds-cpp)
#   - (Optional) NVIDIA CUDA runtime libraries (L4T)
#   - (Optional) cuDNN libraries
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

# Multi-select prompt for NVIDIA libraries
# Sets INSTALL_CUDA, INSTALL_CUDNN, INSTALL_TENSORRT, INSTALL_SPCONV
prompt_nvidia_select() {
    local response

    # Default selections
    [[ -z "$INSTALL_CUDA" ]] && INSTALL_CUDA="y"
    [[ -z "$INSTALL_CUDNN" ]] && INSTALL_CUDNN="y"
    [[ -z "$INSTALL_TENSORRT" ]] && INSTALL_TENSORRT="y"
    [[ -z "$INSTALL_SPCONV" ]] && INSTALL_SPCONV="y"

    while true; do
        # Clear screen and print menu
        clear
        echo ""
        echo "Select NVIDIA libraries to install (toggle with number, Enter when done):"
        echo ""
        echo "  [1] CUDA runtime    $([ "$INSTALL_CUDA" = "y" ] && echo "[*]" || echo "[ ]")"
        echo "  [2] cuDNN           $([ "$INSTALL_CUDNN" = "y" ] && echo "[*]" || echo "[ ]")"
        echo "  [3] TensorRT        $([ "$INSTALL_TENSORRT" = "y" ] && echo "[*]" || echo "[ ]")"
        echo "  [4] SpConv/Cumm     $([ "$INSTALL_SPCONV" = "y" ] && echo "[*]" || echo "[ ]")"
        echo ""
        echo "  [a] Select all  [n] Select none  [Enter] Continue  [q] Quit"
        echo ""
        read -p "Toggle [1-4/a/n/Enter/q]: " -n 1 -r response
        echo ""

        case "$response" in
            1) [[ "$INSTALL_CUDA" = "y" ]] && INSTALL_CUDA="n" || INSTALL_CUDA="y" ;;
            2) [[ "$INSTALL_CUDNN" = "y" ]] && INSTALL_CUDNN="n" || INSTALL_CUDNN="y" ;;
            3) [[ "$INSTALL_TENSORRT" = "y" ]] && INSTALL_TENSORRT="n" || INSTALL_TENSORRT="y" ;;
            4) [[ "$INSTALL_SPCONV" = "y" ]] && INSTALL_SPCONV="n" || INSTALL_SPCONV="y" ;;
            [Aa]) INSTALL_CUDA="y"; INSTALL_CUDNN="y"; INSTALL_TENSORRT="y"; INSTALL_SPCONV="y" ;;
            [Nn]) INSTALL_CUDA="n"; INSTALL_CUDNN="n"; INSTALL_TENSORRT="n"; INSTALL_SPCONV="n" ;;
            "") clear; return 0 ;;
            [Qq]) clear; log_warn "Installation cancelled by user."; exit 1 ;;
            *) ;; # Invalid input - just redraw on next loop
        esac
    done
}

# =============================================================================
# Parse command line arguments
# =============================================================================
INSTALL_ROS=""
INSTALL_CUDA=""
INSTALL_CUDNN=""
INSTALL_TENSORRT=""
INSTALL_SPCONV=""
NVIDIA_PROMPTED=""  # Track if user was prompted for NVIDIA

show_help() {
    head -24 "$0" | tail -22
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
        --cuda)
            INSTALL_CUDA="y"
            shift
            ;;
        --cudnn)
            INSTALL_CUDNN="y"
            shift
            ;;
        --tensorrt)
            INSTALL_TENSORRT="y"
            shift
            ;;
        --spconv)
            INSTALL_SPCONV="y"
            shift
            ;;
        --all-nvidia)
            INSTALL_CUDA="y"
            INSTALL_CUDNN="y"
            INSTALL_TENSORRT="y"
            INSTALL_SPCONV="y"
            NVIDIA_PROMPTED="y"
            shift
            ;;
        --no-nvidia)
            INSTALL_CUDA="n"
            INSTALL_CUDNN="n"
            INSTALL_TENSORRT="n"
            INSTALL_SPCONV="n"
            NVIDIA_PROMPTED="y"
            shift
            ;;
        -y|--yes)
            INSTALL_ROS="y"
            INSTALL_CUDA="y"
            INSTALL_CUDNN="y"
            INSTALL_TENSORRT="y"
            INSTALL_SPCONV="y"
            NVIDIA_PROMPTED="y"
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
    log_error "This script is for arm64 architecture (detected: $ARCH)"
    exit 1
fi

log_info "Setting up Autoware 1.5.0 prerequisites on Ubuntu 22.04 (arm64/JetPack 6.2)"

# =============================================================================
# Interactive prompts (if not specified via command line)
# =============================================================================
echo ""
echo "=============================================="
echo "  Autoware 1.5.0 Prerequisites Setup"
echo "=============================================="
echo ""
echo "This script will install prerequisites for Autoware."
echo "Press 'q' at any prompt or Ctrl-C to cancel."
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

# Prompt for NVIDIA libraries installation
if [ -z "$NVIDIA_PROMPTED" ]; then
    log_warn "Some Autoware components depend on NVIDIA CUDA, cuDNN, and TensorRT libraries."
    echo ""
    echo "  License agreements:"
    echo "  - CUDA EULA:     https://docs.nvidia.com/cuda/eula/index.html"
    echo "  - cuDNN SLLA:    https://docs.nvidia.com/deeplearning/cudnn/sla/index.html"
    echo "  - TensorRT SLLA: https://docs.nvidia.com/deeplearning/tensorrt/sla/index.html"
    echo ""
    if prompt_yNq "Install NVIDIA libraries?"; then
        prompt_nvidia_select
    else
        INSTALL_CUDA="n"
        INSTALL_CUDNN="n"
        INSTALL_TENSORRT="n"
        INSTALL_SPCONV="n"
    fi
    echo ""
fi

# Summary and confirmation
nvidia_summary() {
    local parts=()
    [[ "$INSTALL_CUDA" = "y" ]] && parts+=("CUDA")
    [[ "$INSTALL_CUDNN" = "y" ]] && parts+=("cuDNN")
    [[ "$INSTALL_TENSORRT" = "y" ]] && parts+=("TensorRT")
    [[ "$INSTALL_SPCONV" = "y" ]] && parts+=("SpConv")
    if [[ ${#parts[@]} -eq 0 ]]; then
        echo "No"
    else
        IFS=', '; echo "${parts[*]}"
    fi
}

while true; do
    echo "Installation plan:"
    echo "  - ROS 2 Humble:     $([ "$INSTALL_ROS" = "y" ] && echo "Yes" || echo "No")"
    echo "  - NVIDIA libraries: $(nvidia_summary)"
    echo ""

    read -p "Proceed with installation? [Y/n/r(retry)/q]: " -n 1 -r
    echo ""
    case "$REPLY" in
        [Yy]|"") break ;;  # Continue with installation
        [Rr])
            # Reset and restart prompts
            INSTALL_ROS=""
            NVIDIA_PROMPTED=""
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
# Step 2: NVIDIA Libraries (optional)
# =============================================================================
NVIDIA_ANY="n"
[[ "$INSTALL_CUDA" = "y" || "$INSTALL_CUDNN" = "y" || "$INSTALL_TENSORRT" = "y" || "$INSTALL_SPCONV" = "y" ]] && NVIDIA_ANY="y"

if [ "$NVIDIA_ANY" = "y" ]; then
    log_info "Step 2/2: Installing NVIDIA libraries..."

    # Set up NVIDIA L4T APT sources (r36.4 for JetPack 6.2)
    if [ ! -f /etc/apt/sources.list.d/nvidia-l4t-apt-source.list ]; then
        apt-key adv --fetch-key http://repo.download.nvidia.com/jetson/jetson-ota-public.asc
        echo "deb https://repo.download.nvidia.com/jetson/common r36.4 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
        echo "deb https://repo.download.nvidia.com/jetson/t234 r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
        mkdir -p /opt/nvidia/l4t-packages
        touch /opt/nvidia/l4t-packages/.nv-l4t-disable-boot-fw-update-in-preinstall
    fi

    apt-get update

    # Install CUDA runtime libraries (L4T)
    if [ "$INSTALL_CUDA" = "y" ]; then
        log_info "Installing CUDA runtime libraries..."
        apt-get install -o DPkg::Options::="--force-confold" -y \
            nvidia-l4t-core \
            nvidia-l4t-cuda
    fi

    # Install cuDNN
    if [ "$INSTALL_CUDNN" = "y" ]; then
        log_info "Installing cuDNN..."
        apt-get install -o DPkg::Options::="--force-confold" -y \
            libcudnn9-cuda-12
    fi

    # Install TensorRT (included in L4T base image for JetPack 6.2)
    if [ "$INSTALL_TENSORRT" = "y" ]; then
        log_info "Installing TensorRT..."
        apt-get install -o DPkg::Options::="--force-confold" -y \
            libnvinfer10 \
            libnvinfer-plugin10 \
            libnvonnxparsers10
    fi

    # Install SpConv and Cumm (for BEVFusion and other perception models)
    if [ "$INSTALL_SPCONV" = "y" ]; then
        log_info "Installing SpConv and Cumm..."
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
    fi

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
echo "     sudo apt-get install autoware-full-1-5-0"
echo ""
echo "  2. Source the environment:"
echo "     source /opt/autoware/1.5.0/setup.bash"
echo ""
