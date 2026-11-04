#!/usr/bin/env bash
# Test autoware-localrepo installation in a clean Docker container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(dirname "$SCRIPT_DIR")"
# Newest revision: packages/ keeps every localrepo deb ever built.
DEB_FILE="$(ls "$BASEDIR/packages/autoware-localrepo-1-7-1_"*_all.deb 2>/dev/null | sort -V | tail -1)"

for f in "$DEB_FILE"; do
    if [ ! -f "$f" ]; then
        echo "Error: $f not found. Run 'just all' first."
        exit 1
    fi
done

echo "Testing autoware-localrepo installation..."
echo "  Package: $DEB_FILE"
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
docker build -t autoware-localrepo-test:1.7.1 "$TMPDIR"

echo ""
echo "Test passed! autoware-localrepo installs correctly."
echo "  - autoware-full installed successfully"
echo "  - setup.bash sources without errors"
