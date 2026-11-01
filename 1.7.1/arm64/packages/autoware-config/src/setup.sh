#!/bin/sh
# Autoware 1.7.1 workspace environment setup (POSIX sh)
# Usage: . /opt/autoware/1.7.1/setup.sh

AUTOWARE_VERSION="1.7.1"
AUTOWARE_HOME="/opt/autoware/1.7.1"
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
unset AMENT_CURRENT_PREFIX

# Source Autoware local setup using ament approach
if [ -f "$AUTOWARE_HOME/local_setup.sh" ]; then
    . "$AUTOWARE_HOME/local_setup.sh"
else
    echo "Error: Autoware local_setup.sh not found" >&2
    return 1
fi
