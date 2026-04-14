#!/usr/bin/env bash
# Autoware 1.7.1 runtime environment configuration
# Sets DDS, CycloneDDS, and GUI environment variables.
#
# Usage: source /opt/autoware/1.7.1/autoware-env.bash

if [ -z "$AUTOWARE_HOME" ]; then
    echo "Error: AUTOWARE_HOME is not set. Source setup.bash first." >&2
    return 1
fi

# CycloneDDS
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI="file://$AUTOWARE_HOME/config/cyclonedds.xml"
unset ROS_LOCALHOST_ONLY

# Qt theme for RViz
export QT_QPA_PLATFORMTHEME=qt5ct
