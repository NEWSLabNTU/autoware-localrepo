#!/bin/sh
# Autoware 1.5.0 environment setup script (POSIX sh)
# Usage: . /opt/autoware/1.5.0/setup.sh

AUTOWARE_VERSION="1.5.0"
AUTOWARE_HOME="/opt/autoware/1.5.0"
export AUTOWARE_VERSION AUTOWARE_HOME

# Source ROS 2 Humble base
if [ -f /opt/ros/humble/setup.sh ]; then
    . /opt/ros/humble/setup.sh
else
    echo "Error: ROS 2 Humble not found at /opt/ros/humble" >&2
    return 1
fi

# Clear AMENT_CURRENT_PREFIX leaked by ROS setup.sh (it sets this in its
# local_setup loop for AMENT_SHELL=sh but never unsets it afterward).
# Without this, Autoware's local_setup.sh picks up the stale /opt/ros/humble
# prefix and runs the wrong _local_setup_util.py.
unset AMENT_CURRENT_PREFIX

# Source Autoware local setup using ament approach
# This properly sets up all package-level environment variables via DSV files
if [ -f "$AUTOWARE_HOME/local_setup.sh" ]; then
    . "$AUTOWARE_HOME/local_setup.sh"
else
    echo "Error: Autoware local_setup.sh not found" >&2
    return 1
fi

# Configure RMW implementation
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export RMW_IMPLEMENTATION

# Unset ROS_LOCALHOST_ONLY if present
if [ -n "$ROS_LOCALHOST_ONLY" ]; then
    echo "Warning: ROS_LOCALHOST_ONLY was set. Unsetting for CycloneDDS compatibility." >&2
    unset ROS_LOCALHOST_ONLY
fi

# Check network configuration and enable CycloneDDS config
multicast=false
network_ok=false

if (ip link show lo | grep -q "MULTICAST") 2>/dev/null; then
    multicast=true
fi

if [ "$(sysctl -n net.core.rmem_max 2>/dev/null)" = "2147483647" ] && \
   [ "$(sysctl -n net.ipv4.ipfrag_time 2>/dev/null)" = "3" ] && \
   [ "$(sysctl -n net.ipv4.ipfrag_high_thresh 2>/dev/null)" = "134217728" ]; then
    network_ok=true
fi

if [ "$multicast" = "true" ] && [ "$network_ok" = "true" ]; then
    CYCLONEDDS_URI="file://$AUTOWARE_HOME/config/cyclonedds.xml"
    export CYCLONEDDS_URI
else
    echo "Warning: Network not configured for optimal DDS performance." >&2
    echo "Warning: Run 'sudo systemctl start multicast-lo' and check sysctl settings." >&2
fi

unset multicast network_ok

# Qt theme for RViz
QT_QPA_PLATFORMTHEME=qt5ct
export QT_QPA_PLATFORMTHEME

echo "Autoware $AUTOWARE_VERSION environment loaded."
