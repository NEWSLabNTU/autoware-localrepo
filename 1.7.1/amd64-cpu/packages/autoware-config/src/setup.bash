#!/usr/bin/env bash
# Autoware 1.7.1 workspace environment setup
# Usage: source /opt/autoware/1.7.1/setup.bash

export AUTOWARE_VERSION="1.7.1"
export AUTOWARE_HOME="/opt/autoware/1.7.1"

# Source ROS 2 Humble base
if [ -f /opt/ros/humble/setup.bash ]; then
    source /opt/ros/humble/setup.bash
else
    echo "Error: ROS 2 Humble not found at /opt/ros/humble" >&2
    return 1
fi

# Source Autoware local setup using ament approach
if [ -f "$AUTOWARE_HOME/local_setup.bash" ]; then
    source "$AUTOWARE_HOME/local_setup.bash"
else
    echo "Error: Autoware local_setup.bash not found" >&2
    return 1
fi
