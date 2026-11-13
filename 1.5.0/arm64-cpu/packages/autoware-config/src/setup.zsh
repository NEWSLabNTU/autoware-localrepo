#!/usr/bin/env zsh
# Autoware 1.5.0 workspace environment setup
# Usage: source /opt/autoware/1.5.0/setup.zsh

export AUTOWARE_VERSION="1.5.0"
export AUTOWARE_HOME="/opt/autoware/1.5.0"

# Source ROS 2 Humble base
if [ -f /opt/ros/humble/setup.zsh ]; then
    source /opt/ros/humble/setup.zsh
else
    echo "Error: ROS 2 Humble not found at /opt/ros/humble" >&2
    return 1
fi

# Source Autoware local setup using ament approach
if [ -f "$AUTOWARE_HOME/local_setup.zsh" ]; then
    source "$AUTOWARE_HOME/local_setup.zsh"
else
    echo "Error: Autoware local_setup.zsh not found" >&2
    return 1
fi
