#!/bin/bash
# Generate debian/control from build/debs directory
#
# Usage: ./genpkg.sh [debs_dir]
#   debs_dir: Path to directory containing .deb files (default: ../../build/debs)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBS_DIR="${1:-$SCRIPT_DIR/../../build/debs}"

if [ ! -d "$DEBS_DIR" ]; then
    echo "Error: Debs directory not found: $DEBS_DIR" >&2
    exit 1
fi

# Count packages
PKG_COUNT=$(ls -1 "$DEBS_DIR"/*.deb 2>/dev/null | grep -v dbgsym | wc -l)
if [ "$PKG_COUNT" -eq 0 ]; then
    echo "Error: No .deb files found in $DEBS_DIR" >&2
    exit 1
fi

echo "Generating debian/control from $PKG_COUNT packages in $DEBS_DIR"

# Generate control file
cat > "$SCRIPT_DIR/debian/control" << 'HEADER'
Source: autoware-ros-packages
Section: misc
Priority: optional
Maintainer: Jerry Lin <jerry73204@gmail.com>
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.6.2

Package: autoware-ros-packages
Architecture: any
Depends: ${misc:Depends},
HEADER

# Add package dependencies (exclude dbgsym, remove trailing comma from last)
ls -1 "$DEBS_DIR"/*.deb | grep -v dbgsym | xargs -I{} basename {} .deb | sed 's/_.*$//' | sort -u | sed 's/^/         /' | sed '$ ! s/$/,/' >> "$SCRIPT_DIR/debian/control"

# Add description
cat >> "$SCRIPT_DIR/debian/control" << 'FOOTER'
Description: Autoware ROS packages meta-package
 This meta-package depends on all Autoware ROS 2 packages
 built for version 1.5.0.
FOOTER

echo "Generated debian/control with $PKG_COUNT package dependencies"
