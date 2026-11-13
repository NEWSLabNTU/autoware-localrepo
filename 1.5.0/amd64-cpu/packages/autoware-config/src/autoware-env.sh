#!/bin/sh
# Autoware 1.5.0 runtime environment configuration (POSIX sh)
# Sets DDS, CycloneDDS, and GUI environment variables.
#
# Usage: . /opt/autoware/1.5.0/autoware-env.sh

if [ -z "$AUTOWARE_HOME" ]; then
    echo "Error: AUTOWARE_HOME is not set. Source setup.sh first." >&2
    return 1
fi

# CycloneDDS
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
CYCLONEDDS_URI="file://$AUTOWARE_HOME/config/cyclonedds.xml"
export RMW_IMPLEMENTATION CYCLONEDDS_URI
unset ROS_LOCALHOST_ONLY

# Qt theme for RViz
QT_QPA_PLATFORMTHEME=qt5ct
export QT_QPA_PLATFORMTHEME
