#!/usr/bin/env bash
# Autoware 1.5.0 local setup script (does not source ROS base)
# Usage: source /opt/autoware/1.5.0/local_setup.bash

_AUTOWARE_HOME="/opt/autoware/1.5.0"

# Set up Autoware workspace paths
export AMENT_PREFIX_PATH="$_AUTOWARE_HOME${AMENT_PREFIX_PATH:+:$AMENT_PREFIX_PATH}"
export CMAKE_PREFIX_PATH="$_AUTOWARE_HOME${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export COLCON_PREFIX_PATH="$_AUTOWARE_HOME${COLCON_PREFIX_PATH:+:$COLCON_PREFIX_PATH}"
export PATH="$_AUTOWARE_HOME/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$_AUTOWARE_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="$_AUTOWARE_HOME/lib/python3.10/site-packages${PYTHONPATH:+:$PYTHONPATH}"

unset _AUTOWARE_HOME
