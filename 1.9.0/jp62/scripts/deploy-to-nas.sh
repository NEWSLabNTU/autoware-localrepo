#!/usr/bin/env bash
# Sign the bundled repository and publish it to a Synology NAS over rsync/SSH.
#
# Reads deploy.env (gitignored) for the target and signing key. Run after
# `just localrepo`, which assembles packages/autoware-localrepo/repo/.
#
# Publishing is atomic: everything lands in a staging directory and a symlink
# is swapped at the end, so apt clients never see a Packages index that
# references .debs which have not finished uploading.

set -euo pipefail

VERSION="${1:?usage: deploy-to-nas.sh <version> <arch-label>}"
ARCH_LABEL="${2:?usage: deploy-to-nas.sh <version> <arch-label>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(dirname "$SCRIPT_DIR")"
REPODIR="$BASEDIR/packages/autoware-localrepo/repo"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- configuration ---------------------------------------------------------
if [ ! -f "$BASEDIR/deploy.env" ]; then
    log_error "deploy.env not found."
    echo "    cp deploy.env.example deploy.env    # then fill it in"
    echo "  It is gitignored on purpose -- this repository is public."
    exit 1
fi
# shellcheck disable=SC1091
source "$BASEDIR/deploy.env"

for var in NAS_HOST NAS_USER NAS_PATH REPO_BASE_URL GPG_KEY_ID; do
    if [ -z "${!var:-}" ]; then
        log_error "$var is not set in deploy.env"
        exit 1
    fi
done
if [ "$GPG_KEY_ID" = "0000000000000000" ]; then
    log_error "GPG_KEY_ID is still the placeholder from deploy.env.example."
    exit 1
fi

if [ ! -d "$REPODIR/pool/main" ]; then
    log_error "$REPODIR/pool/main not found. Run 'just localrepo' first."
    exit 1
fi

# --- preflight -------------------------------------------------------------
if ! gpg --list-secret-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
    log_error "No secret key for $GPG_KEY_ID in this keyring."
    echo "  Generate one with:"
    echo "    gpg --quick-generate-key \"Your Repo <you@example.com>\" rsa4096 sign never"
    exit 1
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$NAS_USER@$NAS_HOST" true 2>/dev/null; then
    log_error "Cannot SSH to $NAS_USER@$NAS_HOST with key auth."
    echo "  Enable SSH:  DSM > Control Panel > Terminal & SNMP > Enable SSH service"
    echo "  Install key: ssh-copy-id $NAS_USER@$NAS_HOST"
    exit 1
fi

REMOTE_ROOT="$NAS_PATH/$VERSION"
TARGET="$ARCH_LABEL"
STAGING="$ARCH_LABEL.staging"

log_info "Publishing $VERSION/$ARCH_LABEL"
echo "  Source: $REPODIR"
echo "  Target: $NAS_USER@$NAS_HOST:$REMOTE_ROOT/$TARGET"
echo "  URL:    $REPO_BASE_URL/$VERSION/$TARGET"
echo "  Key:    $GPG_KEY_ID"
echo ""

# --- sign the repository ---------------------------------------------------
# dpkg-scanpackages (run by `just localrepo`) writes Packages but no Release,
# which is what apt actually verifies. Generate and sign it here.
log_info "Generating Release..."
( cd "$REPODIR" && rm -f Release Release.gpg InRelease && \
  apt-ftparchive \
      -o "APT::FTPArchive::Release::Origin=NEWSLabNTU" \
      -o "APT::FTPArchive::Release::Label=Autoware $VERSION" \
      -o "APT::FTPArchive::Release::Suite=stable" \
      -o "APT::FTPArchive::Release::Codename=jammy" \
      -o "APT::FTPArchive::Release::Architectures=amd64 arm64 all" \
      -o "APT::FTPArchive::Release::Components=main" \
      -o "APT::FTPArchive::Release::Description=Autoware $VERSION ($ARCH_LABEL)" \
      release . > Release )

log_info "Signing Release with $GPG_KEY_ID..."
( cd "$REPODIR" && \
  gpg --batch --yes --default-key "$GPG_KEY_ID" --clearsign -o InRelease Release && \
  gpg --batch --yes --default-key "$GPG_KEY_ID" -abs -o Release.gpg Release )

# Export the PUBLIC key for clients. Never the private one.
log_info "Exporting public key..."
gpg --export "$GPG_KEY_ID" > "$REPODIR/autoware-archive-keyring.gpg"

# --- upload ----------------------------------------------------------------
log_info "Creating remote directories..."
ssh "$NAS_USER@$NAS_HOST" "mkdir -p '$REMOTE_ROOT/$STAGING'"

# Seed the staging dir from the currently published tree so rsync only has to
# transfer what changed. Without this every deploy re-uploads all 2.5 GB.
log_info "Seeding staging from published tree (if any)..."
ssh "$NAS_USER@$NAS_HOST" \
    "if [ -d '$REMOTE_ROOT/$TARGET' ]; then cp -al '$REMOTE_ROOT/$TARGET/.' '$REMOTE_ROOT/$STAGING/' 2>/dev/null || \
        rsync -a '$REMOTE_ROOT/$TARGET/' '$REMOTE_ROOT/$STAGING/'; fi"

log_info "Uploading (incremental)..."
rsync -a --delete --info=progress2 --human-readable \
      "$REPODIR/" "$NAS_USER@$NAS_HOST:$REMOTE_ROOT/$STAGING/"

# --- atomic publish --------------------------------------------------------
# Swap via a symlink so clients see either the old tree or the new one, never
# a half-uploaded mix.
log_info "Publishing atomically..."
ssh "$NAS_USER@$NAS_HOST" bash -s <<REMOTE
set -euo pipefail
cd '$REMOTE_ROOT'
if [ -L '$TARGET' ] || [ ! -e '$TARGET' ]; then
    # Already symlink-based (or first deploy): swap in place.
    rm -rf '$TARGET.new'
    mv '$STAGING' '$TARGET.new'
    ln -sfn '$TARGET.new' '$TARGET.tmp'
    mv -T '$TARGET.tmp' '$TARGET'
    rm -rf '$TARGET.old'
else
    # First conversion from a real directory to the symlink scheme.
    mv '$TARGET' '$TARGET.old'
    mv '$STAGING' '$TARGET.new'
    ln -sfn '$TARGET.new' '$TARGET'
    rm -rf '$TARGET.old'
fi
REMOTE

log_info "Deployed."
echo ""
echo "Clients install with:"
echo ""
echo "  curl -fsSL $REPO_BASE_URL/$VERSION/$TARGET/autoware-archive-keyring.gpg \\"
echo "      | sudo tee /usr/share/keyrings/autoware-$VERSION.gpg > /dev/null"
echo "  echo \"deb [signed-by=/usr/share/keyrings/autoware-$VERSION.gpg] $REPO_BASE_URL/$VERSION/$TARGET ./\" \\"
echo "      | sudo tee /etc/apt/sources.list.d/autoware-$VERSION.list"
echo "  sudo apt update && sudo apt install autoware-full-${VERSION//./-}"
echo ""
echo "Or ship packages/autoware-localrepo-remote-*.deb, which carries all three."
