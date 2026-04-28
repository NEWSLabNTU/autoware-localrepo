#!/usr/bin/env bash
# Test autoware-localrepo installation in a clean Docker container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(dirname "$SCRIPT_DIR")"
DEB_FILE="$BASEDIR/packages/autoware-localrepo-1-7-1_1.7.1-1ubuntu2204_all.deb"
DATA_FILE="$BASEDIR/packages/autoware-data-1-7-1_1.7.1-1_all.deb"

for f in "$DEB_FILE" "$DATA_FILE"; do
    if [ ! -f "$f" ]; then
        echo "Error: $f not found. Run 'just all' first."
        exit 1
    fi
done

echo "Testing autoware-localrepo installation..."
echo "  Package: $DEB_FILE"
echo "  Data:    $DATA_FILE"
echo ""

# Create temporary directory for Docker context
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Copy the deb files, Dockerfile, and prerequisites script
# (prerequisites script copied separately for better Docker layer caching)
cp "$DEB_FILE" "$TMPDIR/autoware-localrepo.deb"
cp "$DATA_FILE" "$TMPDIR/autoware-data.deb"
cp "$SCRIPT_DIR/Dockerfile" "$TMPDIR/Dockerfile"
cp "$BASEDIR/packages/autoware-localrepo/src/setup-prerequisites.sh" "$TMPDIR/"

# Build the test container
echo "Building test container..."
docker build -t autoware-localrepo-test:1.7.1 "$TMPDIR"

echo ""
echo "Test passed! autoware-localrepo installs correctly."
echo "  - autoware-full installed successfully"
echo "  - setup.bash sources without errors"
