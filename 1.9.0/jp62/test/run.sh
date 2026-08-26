#!/usr/bin/env bash
# Test autoware-localrepo installation in a clean JetPack 6.2 Docker container
#
# NOTE: This builds an arm64 image. On amd64 hosts, it requires:
#   - QEMU user-mode emulation (qemu-user-static)
#   - Docker buildx with platform support
# The build will be VERY slow under QEMU emulation.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(dirname "$SCRIPT_DIR")"
DEB_FILE="$BASEDIR/packages/autoware-localrepo-1-9-0_1.9.0-1jetpack62_all.deb"

# The ML models ship as three topic debs (see packages/autoware-data/groups.yaml);
# a single one would exceed GitHub's 2 GiB release-asset limit.
DATA_FILES=()
for topic in vision perception3d planning; do
    DATA_FILES+=("$BASEDIR/packages/autoware-data-${topic}-1-9-0_1.9.0-1_all.deb")
done

for f in "$DEB_FILE" "${DATA_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "Error: $f not found. Run 'just all' first."
        exit 1
    fi
done

echo "Testing autoware-localrepo installation (JetPack 6.2 / arm64)..."
echo "  Package: $DEB_FILE"
for f in "${DATA_FILES[@]}"; do
    echo "  Data:    $f"
done
echo ""

# Create temporary directory for Docker context
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Copy required files to Docker context
cp "$DEB_FILE" "$TMPDIR/autoware-localrepo.deb"
for f in "${DATA_FILES[@]}"; do
    cp "$f" "$TMPDIR/"
done
cp "$SCRIPT_DIR/Dockerfile" "$TMPDIR/Dockerfile"
cp "$SCRIPT_DIR/opencv-preferences" "$TMPDIR/opencv-preferences"
# The prerequisites script is copied separately from the .deb it ships in, so
# Docker can cache the (slow) prerequisite layer independently of the packages.
cp "$BASEDIR/packages/autoware-localrepo/src/setup-prerequisites.sh" "$TMPDIR/"

# Build the test container (arm64 platform)
echo "Building test container (arm64)..."
docker build --platform linux/arm64 -t autoware-localrepo-test:1.9.0-jp62 "$TMPDIR"

echo ""
echo "Test passed! autoware-localrepo installs correctly on JetPack 6.2."
echo "  - autoware-full installed successfully"
echo "  - setup.bash sources without errors"
