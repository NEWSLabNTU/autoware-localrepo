#!/usr/bin/env zsh
# Autoware 1.5.0 runtime environment configuration
# Sets DDS, CycloneDDS, and GUI environment variables.
#
# Usage: source /opt/autoware/1.5.0/autoware-env.zsh

if [ -z "$AUTOWARE_HOME" ]; then
    echo "Error: AUTOWARE_HOME is not set. Source setup.zsh first." >&2
    return 1
fi

# CycloneDDS
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI="file://$AUTOWARE_HOME/config/cyclonedds.xml"
unset ROS_LOCALHOST_ONLY

# Qt theme for RViz
export QT_QPA_PLATFORMTHEME=qt5ct
