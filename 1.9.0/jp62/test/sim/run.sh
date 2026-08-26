#!/bin/bash
# Autoware 1.9.0 Planning Simulation - Docker Launcher (JetPack 6.2 / arm64)
#
# Launches Docker container with X11 forwarding for planning simulation
#
# Usage: ./run.sh [map_path]
#
# Arguments:
#   map_path  Path to map directory on host (default: ~/autoware_map/sample-map-planning)
#
# Environment variables:
#   VEHICLE_MODEL  Vehicle model name (default: sample_vehicle)
#   SENSOR_MODEL   Sensor kit name (default: sample_sensor_kit)
#   DOCKER_IMAGE   Docker image to use (default: autoware-localrepo-test:1.9.0-jp62)
#
# Web UI:
#   play_launch web interface available at http://<host-ip>:8888
#   (the container runs with --net=host, so no port mapping is needed)
#
# Logs:
#   play_launch logs are saved to ./play_log/ directory
#
# Requirements:
#   - Jetson device running JetPack 6.2, or an arm64 host
#   - GPU access on Jetson comes from the default nvidia runtime; --gpus is not
#     used here because it is an amd64/nvidia-container-toolkit concept

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAP_PATH="${1:-$HOME/autoware_map/sample-map-planning}"
DOCKER_IMAGE="${DOCKER_IMAGE:-autoware-localrepo-test:1.9.0-jp62}"
LOG_DIR="$SCRIPT_DIR/play_log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Check if map exists on host
if [ ! -d "$MAP_PATH" ]; then
    log_error "Map not found at: $MAP_PATH"
    echo ""
    echo "Please download the sample map first:"
    echo "  mkdir -p ~/autoware_map"
    echo "  gdown -O ~/autoware_map/ 'https://docs.google.com/uc?export=download&id=1499_nsbUbIeturZaDj7jhUownh5fvXHd'"
    echo "  unzip -d ~/autoware_map ~/autoware_map/sample-map-planning.zip"
    exit 1
fi

# Check X11
if [ -z "$DISPLAY" ]; then
    log_error "DISPLAY not set. X11 forwarding required for RViz."
    exit 1
fi

# Allow X11 connections from Docker
log_info "Allowing X11 connections..."
xhost +local:docker > /dev/null 2>&1 || true

log_info "Starting Docker container with planning simulation..."
echo "  Image: $DOCKER_IMAGE"
echo "  Map:   $MAP_PATH"
echo "  Logs:  $LOG_DIR"
echo ""

# Use -t only if TTY is available
DOCKER_TTY=""
if [ -t 0 ]; then
    DOCKER_TTY="-t"
fi

# Detect if running under QEMU emulation (x86_64 host running arm64 container)
QEMU_EMULATION=""
if [ "$(uname -m)" = "x86_64" ]; then
    QEMU_EMULATION="1"
    log_info "QEMU emulation detected (x86_64 host)"
fi

docker run -i $DOCKER_TTY --rm \
    --platform linux/arm64 \
    --net=host \
    -e DISPLAY="$DISPLAY" \
    -e VEHICLE_MODEL="${VEHICLE_MODEL:-sample_vehicle}" \
    -e SENSOR_MODEL="${SENSOR_MODEL:-sample_sensor_kit}" \
    -e QEMU_EMULATION="$QEMU_EMULATION" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$MAP_PATH:/autoware_map/sample-map-planning:ro" \
    -v "$LOG_DIR:/play_log" \
    -v "$SCRIPT_DIR/planning-sim.sh:/planning-sim.sh:ro" \
    -w /play_log \
    "$DOCKER_IMAGE" \
    /planning-sim.sh
