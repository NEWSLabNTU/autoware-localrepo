#!/usr/bin/env zsh
# Autoware 2.1.0 workspace environment setup
# Usage: source /opt/autoware/2.1.0/setup.zsh

export AUTOWARE_VERSION="2.1.0"
export AUTOWARE_HOME="/opt/autoware/2.1.0"

# Source ROS 2 Jazzy base
if [ -f /opt/ros/jazzy/setup.zsh ]; then
    source /opt/ros/jazzy/setup.zsh
else
    echo "Error: ROS 2 Jazzy not found at /opt/ros/jazzy" >&2
    return 1
fi

# Source Autoware local setup using ament approach
if [ -f "$AUTOWARE_HOME/local_setup.zsh" ]; then
    source "$AUTOWARE_HOME/local_setup.zsh"
else
    echo "Error: Autoware local_setup.zsh not found" >&2
    return 1
fi
