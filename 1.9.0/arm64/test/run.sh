#!/usr/bin/env bash
# Test autoware-localrepo installation in a clean Docker container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(dirname "$SCRIPT_DIR")"
# Newest revision: packages/ keeps every localrepo deb ever built.
DEB_FILE="$(ls "$BASEDIR/packages/autoware-localrepo-1-9-0_"*_all.deb 2>/dev/null | sort -V | tail -1)"

# The localrepo bundles every package (models are downloaded inside the test),
# so it is the only artifact the test needs.
if [ ! -f "$DEB_FILE" ]; then
    echo "Error: $DEB_FILE not found. Run 'just all' first."
    exit 1
fi

echo "Testing autoware-localrepo installation..."
echo "  Package: $DEB_FILE ($(du -h "$DEB_FILE" | cut -f1))"
echo ""

# Create temporary directory for Docker context
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Copy the deb files, Dockerfile, and prerequisites script
# (prerequisites script copied separately for better Docker layer caching)
cp "$DEB_FILE" "$TMPDIR/autoware-localrepo.deb"
cp "$SCRIPT_DIR/Dockerfile" "$TMPDIR/Dockerfile"
cp "$BASEDIR/packages/autoware-localrepo/src/setup-prerequisites.sh" "$TMPDIR/"

# Build the test container
echo "Building test container..."
docker build -t autoware-localrepo-test:1.9.0-arm64 "$TMPDIR"

echo ""
echo "Test passed! autoware-localrepo installs correctly."
echo "  - autoware-full installed successfully"
echo "  - setup.bash sources without errors"
