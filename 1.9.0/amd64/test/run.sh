#!/usr/bin/env bash
# Test autoware-localrepo installation in a clean Docker container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(dirname "$SCRIPT_DIR")"
DEB_FILE="$BASEDIR/packages/autoware-localrepo-1-9-0_1.9.0-1ubuntu2204_all.deb"

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

echo "Testing autoware-localrepo installation..."
echo "  Package: $DEB_FILE"
for f in "${DATA_FILES[@]}"; do
    echo "  Data:    $f"
done
echo ""

# Create temporary directory for Docker context
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Copy the deb files, Dockerfile, and prerequisites script
# (prerequisites script copied separately for better Docker layer caching)
cp "$DEB_FILE" "$TMPDIR/autoware-localrepo.deb"
for f in "${DATA_FILES[@]}"; do
    cp "$f" "$TMPDIR/"
done
cp "$SCRIPT_DIR/Dockerfile" "$TMPDIR/Dockerfile"
cp "$BASEDIR/packages/autoware-localrepo/src/setup-prerequisites.sh" "$TMPDIR/"

# Build the test container
echo "Building test container..."
docker build -t autoware-localrepo-test:1.9.0 "$TMPDIR"

echo ""
echo "Test passed! autoware-localrepo installs correctly."
echo "  - autoware-full installed successfully"
echo "  - setup.bash sources without errors"
