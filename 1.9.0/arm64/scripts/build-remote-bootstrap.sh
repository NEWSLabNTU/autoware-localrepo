#!/usr/bin/env bash
# Build autoware-localrepo-remote-<ver>: a few-KB deb that points apt at the
# NAS-hosted repository instead of carrying 2.43 GiB of packages itself.
#
# It ships exactly three things:
#   - /etc/apt/sources.list.d/   the signed-by source line
#   - /usr/share/keyrings/       the repository's PUBLIC signing key
#   - /usr/share/autoware/<ver>/ the same helper scripts as the bundled deb
#
# Everything else comes over the network from the NAS.

set -euo pipefail

VERSION="${1:?usage: build-remote-bootstrap.sh <version> <arch-label>}"
ARCH_LABEL="${2:?usage: build-remote-bootstrap.sh <version> <arch-label>}"
SUFFIX="${VERSION//./-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ ! -f "$BASEDIR/deploy.env" ]; then
    log_error "deploy.env not found (cp deploy.env.example deploy.env)."
    exit 1
fi
# shellcheck disable=SC1091
source "$BASEDIR/deploy.env"
: "${REPO_BASE_URL:?REPO_BASE_URL not set in deploy.env}"
: "${GPG_KEY_ID:?GPG_KEY_ID not set in deploy.env}"

if ! gpg --list-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
    log_error "No key $GPG_KEY_ID in this keyring."
    exit 1
fi

PKG="autoware-localrepo-remote-$SUFFIX"
BUILD="$BASEDIR/packages/.remote-bootstrap"
REPO_URL="$REPO_BASE_URL/$VERSION/$ARCH_LABEL"

rm -rf "$BUILD"
mkdir -p "$BUILD/DEBIAN" \
         "$BUILD/etc/apt/sources.list.d" \
         "$BUILD/usr/share/keyrings" \
         "$BUILD/usr/share/autoware/$VERSION"

# Public key only. The private half never leaves the build host.
gpg --export "$GPG_KEY_ID" > "$BUILD/usr/share/keyrings/autoware-$SUFFIX.gpg"

printf 'deb [signed-by=/usr/share/keyrings/autoware-%s.gpg] %s ./\n' \
    "$SUFFIX" "$REPO_URL" \
    > "$BUILD/etc/apt/sources.list.d/autoware-localrepo-remote-$SUFFIX.list"

install -m 755 "$BASEDIR/packages/autoware-localrepo/src/setup-prerequisites.sh" \
               "$BASEDIR/packages/autoware-localrepo/src/activate-dds-config.sh" \
               "$BASEDIR/packages/autoware-localrepo/src/uninstall-autoware.sh" \
               "$BUILD/usr/share/autoware/$VERSION/"

cat > "$BUILD/DEBIAN/control" <<CONTROL
Package: $PKG
Version: $VERSION-1
Section: misc
Priority: optional
Architecture: all
Maintainer: Jerry Lin <jerry73204@gmail.com>
Conflicts: autoware-localrepo-$SUFFIX
Replaces: autoware-localrepo-$SUFFIX
Description: APT source for the hosted Autoware $VERSION repository
 Points apt at the network-hosted Autoware $VERSION repository and installs
 its signing key, so packages are fetched on demand instead of being bundled.
 .
 Use this instead of autoware-localrepo-$SUFFIX when the machine can reach
 the repository host. The bundled variant remains the right choice for
 offline or air-gapped installs.
 .
 Repository: $REPO_URL
CONTROL

cat > "$BUILD/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if [ "$1" = "purge" ] || [ "$1" = "remove" ]; then
    rm -f /etc/apt/sources.list.d/autoware-localrepo-remote-*.list
fi
exit 0
POSTRM
chmod 755 "$BUILD/DEBIAN/postrm"

OUT="$BASEDIR/packages/${PKG}_${VERSION}-1_all.deb"
dpkg-deb --build --root-owner-group "$BUILD" "$OUT" > /dev/null
rm -rf "$BUILD"

log_info "Built $(basename "$OUT") ($(du -h "$OUT" | cut -f1))"
echo ""
echo "  Repository: $REPO_URL"
echo "  Signed by:  $GPG_KEY_ID"
echo ""
echo "Install on a target machine:"
echo "  sudo dpkg -i $(basename "$OUT")"
echo "  sudo /usr/share/autoware/$VERSION/setup-prerequisites.sh -y"
echo "  sudo apt update && sudo apt install autoware-full-$SUFFIX"
echo "  sudo /usr/share/autoware/$VERSION/activate-dds-config.sh"
