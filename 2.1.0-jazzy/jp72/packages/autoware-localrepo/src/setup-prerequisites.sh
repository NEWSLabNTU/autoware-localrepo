#!/bin/bash
# Autoware 2.1.0 Prerequisites Setup Script (JetPack 7.2, Jetson AGX Orin)
#
# For a Jetson Orin flashed with JetPack 7.2 (Jetson Linux r39.2, Ubuntu 24.04).
# The CUDA, cuDNN and TensorRT it installs come from NVIDIA's Jetson apt
# repository (jetson/common r39.2), pinned to the versions the packages were
# built against, and are held so that apt upgrade does not move them:
#   CUDA 13.2.2, cuDNN 9.20.0.46, TensorRT 10.16.2.10
# A JetPack 7.2.1 install already carries exactly these; the script then only
# holds them.
# This script installs all prerequisites needed before installing autoware-localrepo
#
# Usage: sudo ./setup-prerequisites.sh [OPTIONS]
#
# Options:
#   --ros             Install ROS 2 Jazzy
#   --no-ros          Skip ROS 2 installation
#   --cuda            Install CUDA runtime libraries
#   --no-cuda         Skip CUDA runtime libraries
#   --cudnn           Install cuDNN (requires CUDA)
#   --no-cudnn        Skip cuDNN
#   --tensorrt        Install TensorRT (requires CUDA)
#   --no-tensorrt     Skip TensorRT
#   --spconv          Install SpConv/Cumm (requires CUDA)
#   --no-spconv       Skip SpConv/Cumm
#   --all-nvidia      Install all NVIDIA libraries
#   --no-nvidia       Skip all NVIDIA libraries
#   --non-interactive Skip all prompts (unspecified components are skipped)
#   -y, --yes         Install everything non-interactively
#   -h, --help        Show this help message
#
# Examples:
#   sudo ./setup-prerequisites.sh                        # Fully interactive
#   sudo ./setup-prerequisites.sh --ros                  # Install ROS, prompt for NVIDIA
#   sudo ./setup-prerequisites.sh --non-interactive --ros          # Install ROS only
#   sudo ./setup-prerequisites.sh --non-interactive --ros --spconv # Install ROS + SpConv
#   sudo ./setup-prerequisites.sh -y                     # Install everything
#
# Prerequisites installed:
#   - ROS 2 Jazzy (ros-jazzy-ros-base + rmw-cyclonedds-cpp)
#   - (Optional) NVIDIA CUDA runtime libraries
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
NON_INTERACTIVE=""

show_help() {
    head -35 "$0" | tail -33
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --ros|--install-ros)
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
        --no-cuda)
            INSTALL_CUDA="n"
            shift
            ;;
        --cudnn)
            INSTALL_CUDNN="y"
            shift
            ;;
        --no-cudnn)
            INSTALL_CUDNN="n"
            shift
            ;;
        --tensorrt)
            INSTALL_TENSORRT="y"
            shift
            ;;
        --no-tensorrt)
            INSTALL_TENSORRT="n"
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
        --all-nvidia)
            INSTALL_CUDA="y"
            INSTALL_CUDNN="y"
            INSTALL_TENSORRT="y"
            INSTALL_SPCONV="y"
            shift
            ;;
        --no-nvidia)
            INSTALL_CUDA="n"
            INSTALL_CUDNN="n"
            INSTALL_TENSORRT="n"
            INSTALL_SPCONV="n"
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE="y"
            shift
            ;;
        -y|--yes)
            INSTALL_ROS="y"
            INSTALL_CUDA="y"
            INSTALL_CUDNN="y"
            INSTALL_TENSORRT="y"
            INSTALL_SPCONV="y"
            NON_INTERACTIVE="y"
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

# In non-interactive mode, default unspecified components to "n"
if [ "$NON_INTERACTIVE" = "y" ]; then
    [[ -z "$INSTALL_ROS" ]] && INSTALL_ROS="n"
    [[ -z "$INSTALL_CUDA" ]] && INSTALL_CUDA="n"
    [[ -z "$INSTALL_CUDNN" ]] && INSTALL_CUDNN="n"
    [[ -z "$INSTALL_TENSORRT" ]] && INSTALL_TENSORRT="n"
    [[ -z "$INSTALL_SPCONV" ]] && INSTALL_SPCONV="n"
fi

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
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
        log_error "This script requires Ubuntu 24.04 (detected: $ID $VERSION_ID)"
        exit 1
    fi
else
    log_error "Cannot detect OS version"
    exit 1
fi

# Detect architecture
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" != "arm64" ]; then
    log_error "This script is for Jetson (arm64; detected: $ARCH)"
    exit 1
fi
# A JetPack 7.2 device reports "# R39 (release), REVISION: 2.x". No file means
# a container or an arm64 server; proceed, since a container is how this
# localrepo is tested, but say so.
if [ -f /etc/nv_tegra_release ]; then
    if ! grep -q '^# R39 (release), REVISION: 2' /etc/nv_tegra_release; then
        log_error "This localrepo is for JetPack 7.2 (L4T r39.2); this device runs: $(head -1 /etc/nv_tegra_release)"
        log_error "JetPack 6.2 (Ubuntu 22.04) has its own Humble jetpack62 localrepo."
        exit 1
    fi
else
    log_warn "No /etc/nv_tegra_release: not a Jetson (container or arm64 server). Continuing."
fi

log_info "Setting up Autoware 2.1.0 prerequisites on Ubuntu 24.04 (JetPack 7.2)"

# =============================================================================
# Interactive prompts (if not specified via command line)
# =============================================================================
if [ "$NON_INTERACTIVE" != "y" ]; then
    echo ""
    echo "=============================================="
    echo "  Autoware 2.1.0 Prerequisites Setup"
    echo "=============================================="
    echo ""
    echo "This script will install prerequisites for Autoware."
    echo "Press 'q' at any prompt or Ctrl-C to cancel."
    echo ""
fi

# Prompt for ROS installation
if [ -z "$INSTALL_ROS" ]; then
    echo "ROS 2 Jazzy is required for Autoware."
    if prompt_Ynq "Install ROS 2 Jazzy?"; then
        INSTALL_ROS="y"
    else
        INSTALL_ROS="n"
    fi
    echo ""
fi

# Prompt for NVIDIA libraries installation
NVIDIA_ALL_SET=""
[[ -n "$INSTALL_CUDA" && -n "$INSTALL_CUDNN" && -n "$INSTALL_TENSORRT" && -n "$INSTALL_SPCONV" ]] && NVIDIA_ALL_SET="y"

if [ "$NVIDIA_ALL_SET" != "y" ]; then
    log_warn "Some Autoware components depend on NVIDIA CUDA, cuDNN, and TensorRT libraries."
    echo ""
    echo "  License agreements:"
    echo "  - CUDA EULA:     https://docs.nvidia.com/cuda/eula/index.html"
    echo "  - cuDNN SLLA:    https://docs.nvidia.com/deeplearning/cudnn/sla/index.html"
    echo "  - TensorRT SLLA: https://docs.nvidia.com/deeplearning/tensorrt/sla/index.html"
    echo ""
    if prompt_ynq "Install NVIDIA libraries?"; then
        prompt_nvidia_select
    else
        [[ -z "$INSTALL_CUDA" ]] && INSTALL_CUDA="n"
        [[ -z "$INSTALL_CUDNN" ]] && INSTALL_CUDNN="n"
        [[ -z "$INSTALL_TENSORRT" ]] && INSTALL_TENSORRT="n"
        [[ -z "$INSTALL_SPCONV" ]] && INSTALL_SPCONV="n"
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

echo "Installation plan:"
echo "  - ROS 2 Jazzy:     $([ "$INSTALL_ROS" = "y" ] && echo "Yes" || echo "No")"
echo "  - NVIDIA libraries: $(nvidia_summary)"
echo ""

if [ "$NON_INTERACTIVE" != "y" ]; then
    while true; do
        read -p "Proceed with installation? [Y/n/r(retry)/q]: " -n 1 -r
        echo ""
        case "$REPLY" in
            [Yy]|"") break ;;  # Continue with installation
            [Rr])
                # Reset and restart prompts
                INSTALL_ROS=""
                INSTALL_CUDA=""
                INSTALL_CUDNN=""
                INSTALL_TENSORRT=""
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
fi

echo ""

# =============================================================================
# Step 0: Install required tools
# =============================================================================
log_info "Installing required tools..."
apt-get update
apt-get install -y curl wget gnupg lsb-release ca-certificates

# =============================================================================
# Step 1: ROS 2 Jazzy (optional)
# =============================================================================
if [ "$INSTALL_ROS" = "y" ]; then
    log_info "Step 1/2: Installing ROS 2 Jazzy..."

    # Use ros2-apt-source package (recommended method)
    # See: https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html
    if [ ! -f /etc/apt/sources.list.d/ros2.sources ]; then
        # Resolve the latest tag from the release page redirect rather than
        # the GitHub API: the API allows 60 unauthenticated requests per hour
        # per IP, which a shared campus or lab address exhausts, and then the
        # version comes back empty and the download below fetches a 404 page.
        ROS_APT_SOURCE_VERSION=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
            https://github.com/ros-infrastructure/ros-apt-source/releases/latest | sed 's#.*/tag/##')
        case "$ROS_APT_SOURCE_VERSION" in
            ''|*/*) log_error "Could not determine the latest ros-apt-source release"; exit 1 ;;
        esac
        curl -fL -o /tmp/ros2-apt-source.deb \
            "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.noble_all.deb"
        dpkg -i /tmp/ros2-apt-source.deb
        rm /tmp/ros2-apt-source.deb
    fi

    apt-get update
    apt-get install -y ros-jazzy-ros-base ros-jazzy-rmw-cyclonedds-cpp

    log_info "ROS 2 Jazzy installed"
else
    log_info "Step 1/2: Skipping ROS 2 Jazzy (not requested)"
fi

# =============================================================================
# Step 2: NVIDIA Libraries (optional)
# =============================================================================
NVIDIA_ANY="n"
[[ "$INSTALL_CUDA" = "y" || "$INSTALL_CUDNN" = "y" || "$INSTALL_TENSORRT" = "y" || "$INSTALL_SPCONV" = "y" ]] && NVIDIA_ANY="y"

if [ "$NVIDIA_ANY" = "y" ]; then
    log_info "Step 2/2: Installing NVIDIA libraries..."

    # NVIDIA's Jetson repository for r39.2. A JetPack 7.2 device already has
    # it (nvidia-l4t-apt-source); add it only where it is missing.
    if ! grep -rqs 'repo.download.nvidia.com/jetson/common r39.2' /etc/apt/sources.list /etc/apt/sources.list.d/; then
        curl -fsSL https://repo.download.nvidia.com/jetson/jetson-ota-public.asc \
            | gpg --dearmor -o /usr/share/keyrings/jetson-ota-archive-keyring.gpg
        {
            echo "deb [signed-by=/usr/share/keyrings/jetson-ota-archive-keyring.gpg] https://repo.download.nvidia.com/jetson/common r39.2 main"
            echo "deb [signed-by=/usr/share/keyrings/jetson-ota-archive-keyring.gpg] https://repo.download.nvidia.com/jetson/som r39.2 main"
        } > /etc/apt/sources.list.d/nvidia-l4t-r39.2.list
    fi

    apt-get update

    # Install CUDA runtime libraries
    if [ "$INSTALL_CUDA" = "y" ]; then
        log_info "Installing CUDA runtime libraries..."
        apt-get install -y --allow-change-held-packages --allow-downgrades \
            cuda-cudart-13-2=13.2.86-1 \
            cuda-nvrtc-13-2=13.2.86-1 \
            libnvjitlink-13-2=13.2.86-1 \
            libcublas-13-2=13.4.1.3-1 \
            libcurand-13-2=10.4.2.66-1 \
            libcusparse-13-2=12.7.10.12-1 \
            libcusolver-13-2=12.2.0.11-1 \
            libcufft-13-2=12.2.0.57-1
        apt-mark hold cuda-cudart-13-2 cuda-nvrtc-13-2 libnvjitlink-13-2 libcublas-13-2 \
            libcurand-13-2 libcusparse-13-2 libcusolver-13-2 libcufft-13-2
    fi

    # Install cuDNN
    if [ "$INSTALL_CUDNN" = "y" ]; then
        log_info "Installing cuDNN..."
        apt-get install -y --allow-change-held-packages --allow-downgrades \
            libcudnn9-cuda-13=9.20.0.46-1
        apt-mark hold libcudnn9-cuda-13
    fi

    # Install TensorRT
    if [ "$INSTALL_TENSORRT" = "y" ]; then
        log_info "Installing TensorRT..."
        apt-get install -y --allow-change-held-packages --allow-downgrades \
            libnvinfer10=10.16.2.10-1+cuda13.2 \
            libnvinfer-plugin10=10.16.2.10-1+cuda13.2 \
            libnvonnxparsers10=10.16.2.10-1+cuda13.2
        apt-mark hold libnvinfer10 libnvinfer-plugin10 libnvonnxparsers10
    fi

    # Install SpConv and Cumm (for BEVFusion and other perception models)
    if [ "$INSTALL_SPCONV" = "y" ]; then
        log_info "Installing SpConv and Cumm..."
        SPCONV_URL="https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu130-rev1"

        # Create unique temporary files
        CUMM_DEB=$(mktemp /tmp/cumm.XXXXXX.deb)
        SPCONV_DEB=$(mktemp /tmp/spconv.XXXXXX.deb)

        # Download packages
        wget -q "${SPCONV_URL}/cumm_0.5.3_arm64.deb" -O "$CUMM_DEB" || {
            log_error "Failed to download cumm package"
            rm -f "$CUMM_DEB" "$SPCONV_DEB"
            exit 1
        }
        wget -q "${SPCONV_URL}/spconv_2.3.8_arm64.deb" -O "$SPCONV_DEB" || {
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
echo "     sudo apt-get install autoware-full-2-1-0"
echo ""
echo "  2. Source the environment:"
echo "     source /opt/autoware/2.1.0/setup.bash"
echo ""
