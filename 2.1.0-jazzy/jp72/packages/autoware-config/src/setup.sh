#!/bin/sh
# Autoware 2.1.0 workspace environment setup (POSIX sh)
# Usage: . /opt/autoware/2.1.0/setup.sh

AUTOWARE_VERSION="2.1.0"
AUTOWARE_HOME="/opt/autoware/2.1.0"
export AUTOWARE_VERSION AUTOWARE_HOME

# Source ROS 2 Jazzy base
if [ -f /opt/ros/jazzy/setup.sh ]; then
    . /opt/ros/jazzy/setup.sh
else
    echo "Error: ROS 2 Jazzy not found at /opt/ros/jazzy" >&2
    return 1
fi

# Clear AMENT_CURRENT_PREFIX leaked by ROS setup.sh (it sets this in its
# local_setup loop for AMENT_SHELL=sh but never unsets it afterward).
unset AMENT_CURRENT_PREFIX

# Source Autoware local setup using ament approach
if [ -f "$AUTOWARE_HOME/local_setup.sh" ]; then
    . "$AUTOWARE_HOME/local_setup.sh"
else
    echo "Error: Autoware local_setup.sh not found" >&2
    return 1
fi
