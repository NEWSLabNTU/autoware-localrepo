#!/usr/bin/env bash
# Test autoware-localrepo installation in a clean Docker container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(dirname "$SCRIPT_DIR")"
DEB_FILE=$(ls "$BASEDIR/packages/autoware-localrepo-1-5-0_"*ubuntu2204_all.deb 2>/dev/null | head -1)

if [ -z "$DEB_FILE" ] || [ ! -f "$DEB_FILE" ]; then
    echo "Error: autoware-localrepo deb not found in $BASEDIR/packages/. Run 'just localrepo' first."
    exit 1
fi

echo "Testing autoware-localrepo installation..."
echo "  Package: $DEB_FILE"
echo ""

# Create temporary directory for Docker context
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Copy the deb file, Dockerfile, and prerequisites script
# (prerequisites script copied separately for better Docker layer caching)
cp "$DEB_FILE" "$TMPDIR/autoware-localrepo.deb"
cp "$SCRIPT_DIR/Dockerfile" "$TMPDIR/Dockerfile"
cp "$BASEDIR/packages/autoware-localrepo/src/setup-prerequisites.sh" "$TMPDIR/"

# Build the test container
echo "Building test container..."
docker build -t autoware-localrepo-test:1.5.0 "$TMPDIR"

echo ""
echo "Test passed! autoware-localrepo installs correctly."
echo "  - autoware-full installed successfully"
echo "  - setup.bash sources without errors"
