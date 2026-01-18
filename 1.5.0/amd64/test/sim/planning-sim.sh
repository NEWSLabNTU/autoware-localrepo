#!/bin/bash
# Autoware 1.5.0 Planning Simulation - Container Entry Point
#
# Launches ROS2 planning simulator inside the container
#
# Usage: /planning-sim.sh [map_path]
#
# Arguments:
#   map_path  Path to map directory (default: /autoware_map/sample-map-planning)
#
# Environment variables:
#   VEHICLE_MODEL  Vehicle model name (default: sample_vehicle)
#   SENSOR_MODEL   Sensor kit name (default: sample_sensor_kit)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

MAP_PATH="${1:-/autoware_map/sample-map-planning}"
VEHICLE_MODEL="${VEHICLE_MODEL:-sample_vehicle}"
SENSOR_MODEL="${SENSOR_MODEL:-sample_sensor_kit}"

# Check if map exists
if [ ! -d "$MAP_PATH" ]; then
    log_error "Map not found at: $MAP_PATH"
    echo ""
    echo "Please download the sample map first (on host machine):"
    echo "  mkdir -p ~/autoware_map"
    echo "  gdown -O ~/autoware_map/ 'https://docs.google.com/uc?export=download&id=1499_nsbUbIeturZaDj7jhUownh5fvXHd'"
    echo "  unzip -d ~/autoware_map ~/autoware_map/sample-map-planning.zip"
    exit 1
fi

# Install play_launch if not available
if ! command -v play_launch &> /dev/null; then
    log_info "Installing play_launch..."
    pip3 install -q play_launch==0.4.0
fi

# Source Autoware environment
log_info "Sourcing Autoware environment..."
source /opt/autoware/1.5.0/setup.bash

log_info "Starting Planning Simulation"
echo "  Map path:      $MAP_PATH"
echo "  Vehicle model: $VEHICLE_MODEL"
echo "  Sensor model:  $SENSOR_MODEL"
echo ""
log_info "RViz will open shortly. To use the simulation:"
echo "  1. Press 'P' to set initial pose (drag to set orientation)"
echo "  2. Press 'G' to set goal pose"
echo "  3. Click 'Auto' button to start autonomous driving"
echo ""
log_info "play_launch web UI available at http://localhost:8888"
echo ""

# Launch planning simulator
play_launch launch \
    --web-ui-addr 0.0.0.0 \
    --web-ui-port 8888 \
    autoware_launch planning_simulator.launch.xml \
    map_path:="$MAP_PATH" \
    vehicle_model:="$VEHICLE_MODEL" \
    sensor_model:="$SENSOR_MODEL"
