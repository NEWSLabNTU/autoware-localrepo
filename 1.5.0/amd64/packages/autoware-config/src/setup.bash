#!/usr/bin/env bash
# Autoware 1.5.0 environment setup script
# Usage: source /opt/autoware/1.5.0/setup.bash

export AUTOWARE_VERSION="1.5.0"
export AUTOWARE_HOME="/opt/autoware/1.5.0"

# Source ROS 2 Humble base
if [ -f /opt/ros/humble/setup.bash ]; then
    source /opt/ros/humble/setup.bash
else
    echo "Error: ROS 2 Humble not found at /opt/ros/humble" >&2
    return 1
fi

# Set up Autoware workspace paths
export AMENT_PREFIX_PATH="$AUTOWARE_HOME:$AMENT_PREFIX_PATH"
export CMAKE_PREFIX_PATH="$AUTOWARE_HOME:$CMAKE_PREFIX_PATH"
export COLCON_PREFIX_PATH="$AUTOWARE_HOME:$COLCON_PREFIX_PATH"
export PATH="$AUTOWARE_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$AUTOWARE_HOME/lib:$LD_LIBRARY_PATH"
export PYTHONPATH="$AUTOWARE_HOME/lib/python3.10/site-packages:$PYTHONPATH"

# Configure RMW implementation
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Unset ROS_LOCALHOST_ONLY if present (incompatible with CycloneDDS config)
if [[ -v ROS_LOCALHOST_ONLY ]]; then
    echo "Warning: ROS_LOCALHOST_ONLY was set. Unsetting for CycloneDDS compatibility." >&2
    unset ROS_LOCALHOST_ONLY
fi

# Check network configuration and enable CycloneDDS config
_autoware_check_network() {
    local multicast=false
    local network_ok=false

    if (ip link show lo | grep -q "MULTICAST") 2>/dev/null; then
        multicast=true
    fi

    if [ "$(sysctl -n net.core.rmem_max 2>/dev/null)" = "2147483647" ] && \
       [ "$(sysctl -n net.ipv4.ipfrag_time 2>/dev/null)" = "3" ] && \
       [ "$(sysctl -n net.ipv4.ipfrag_high_thresh 2>/dev/null)" = "134217728" ]; then
        network_ok=true
    fi

    if $multicast && $network_ok; then
        export CYCLONEDDS_URI="file://$AUTOWARE_HOME/config/cyclonedds.xml"
    else
        echo "Warning: Network not configured for optimal DDS performance." >&2
        echo "Warning: Run 'sudo systemctl start multicast-lo' and check sysctl settings." >&2
    fi
}
_autoware_check_network
unset -f _autoware_check_network

# Qt theme for RViz
export QT_QPA_PLATFORMTHEME=qt5ct

echo "Autoware $AUTOWARE_VERSION environment loaded."
